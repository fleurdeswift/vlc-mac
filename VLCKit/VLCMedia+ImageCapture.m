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

- (void)generatePreviewImageAt:(NSTimeInterval)time
               withMediaPlayer:(VLCMediaPlayer*)mediaPlayer
              completionHander:(nonnull void (^)(__nullable CGImageRef image, __nullable NSError* error))handler {
}

- (void)generatePreviewImageAt:(NSTimeInterval)time
              completionHander:(nonnull void (^)(__nullable CGImageRef image, __nullable NSError* error))handler {
    if (!self.parsed) {
        [self parse];
    }

    NSError*        error       = nil;
    VLCMediaPlayer* mediaPlayer = [[VLCMediaPlayer alloc] initWithMedia:self error:&error];
    
    if (mediaPlayer == nil) {
        handler(nil, error);
        return;
    }

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
    
    [mediaPlayer setTime:time completionBlock:^{
        //[mediaPlayer pause];
        [view captureNextFrame:^(CGImageRef imageRef) {
            [mediaPlayer stop];
            [view description];
            handler(imageRef, nil);
        }];
    }];
    
}

- (void)generatePreviewImagesAtStart:(NSTimeInterval)start
                                 end:(NSTimeInterval)end
                               count:(NSInteger)count
                    completionHander:(nonnull void (^)(__nullable NSArray* images, __nullable NSError* error))handler {
}

@end

