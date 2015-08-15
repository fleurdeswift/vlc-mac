//
//  VLCMedia+ImageCapture.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMedia.h"
#import "VLCMedia+Private.h"

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"

#import "VLC.h"
#import "VLC+Private.h"
#import "VLCIOSurface.h"
#import "VLCOpenGLView.h"

@implementation VLCMedia (ImageCapture)

- (void)generatePreviewImageFor:(NSArray<NSNumber*>*)time
               completionHander:(void (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    if (time.count == 0) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        return;
    }
    
    if (!self.parsed) {
        [self parse];
    }

    NSError*        error       = nil;
    VLCMediaPlayer* mediaPlayer = [[VLCMediaPlayer alloc] initWithMedia:self error:&error];
    
    if (mediaPlayer == nil) {
        handler(nil, error);
        return;
    }
    
    [mediaPlayer setAudioModule:@"adummy"];

    VLCOpenGLView* view    = [[VLCOpenGLView alloc] init];
    CFTypeRef      surface = (__bridge CFTypeRef)view;
    
    libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surface);
    
    [mediaPlayer play];
    mediaPlayer.paused = YES;
    
    if (!mediaPlayer.seekable) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTSUP userInfo:@{
            NSLocalizedDescriptionKey: @"Media isn't seekable"
        }]);
        return;
    }
    
    NSMutableArray<NSNumber*> *remaining = [time mutableCopy];
    
    __block void (^captureFrameBlock)(VLCMediaPlayer *mediaPlayer, NSTimeInterval time) = ^(VLCMediaPlayer *mediaPlayer, NSTimeInterval time) {
        if (time < 0) {
            // Error seeking...
            captureFrameBlock = nil;
            handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
            return;
        }
    
        [view captureNextFrame:^(CGImageRef imageRef) {
            @try {
                handler(imageRef, nil);
            }
            @finally {
                [remaining removeObjectAtIndex:0];
                
                if (remaining.count == 0) {
                    [mediaPlayer stop];
                    captureFrameBlock = nil;
                    handler(nil, nil);
                    [view description];
                    return;
                }
                
                NSTimeInterval nextTime = [remaining firstObject].floatValue;
                NSTimeInterval duration = mediaPlayer.duration - 0.01;
                
                if (nextTime > duration) {
                    nextTime = duration;
                }
                
                [mediaPlayer setTime:nextTime completionBlock:captureFrameBlock];
            }
        }];
    };
    
    [mediaPlayer setTime:[time firstObject].floatValue completionBlock:captureFrameBlock];
}

- (void)generatePreviewImageAt:(NSTimeInterval)time
              completionHander:(void (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    [self generatePreviewImageFor:@[@(time)] completionHander:handler];
}

- (void)generatePreviewImagesAtStart:(NSTimeInterval)start
                                 end:(NSTimeInterval)end
                               count:(NSInteger)count
                    completionHander:(void (^ __nonnull)(NSArray* __nullable images, NSError* __nullable error))handler {
    NSTimeInterval duration = self.duration - 0.01;
    
    if (start < 0) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        return;
    }
    
    if (end > duration) {
        end = duration;
    }
    
    if (start > end) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        return;
    }
    
    NSTimeInterval             length  = (end - start) / (NSTimeInterval)count;
    NSMutableArray<NSNumber*>* times   = [NSMutableArray array];
    NSTimeInterval             current = start;
    
    for (NSInteger index = 0; index < count; ++index, current += length) {
        [times addObject:@(current)];
    }
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:count];
    
    [self generatePreviewImageFor:times completionHander:^(CGImageRef image, NSError* error) {
        if (image != NULL) {
            [results addObject:(__bridge id)image];
        }
        else {
            handler(results, error);
        }
    }];
}

@end

