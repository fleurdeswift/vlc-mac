//
//  VLCMedia.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VLC;
@class VLCMediaTrack;

extern NSString* __nonnull VLCMediaMetaChanged;
extern NSString* __nonnull VLCMediaDurationChanged;
extern NSString* __nonnull VLCMediaStateChanged;
extern NSString* __nonnull VLCMediaSubItemAdded;
extern NSString* __nonnull VLCMediaParsedChanged;

typedef NS_ENUM(NSInteger, VLCMediaState) {
    VLCMediaStateNothingSpecial = 0,
    VLCMediaStateOpening,
    VLCMediaStateBuffering,
    VLCMediaStatePlaying,
    VLCMediaStatePaused,
    VLCMediaStateStopped,
    VLCMediaStateEnded,
    VLCMediaStateError
};

@interface VLCMedia : NSObject
- (nullable instancetype)initWithPath:(nonnull NSString*)filePath withVLC:(nonnull VLC*)vlc error:(out NSError * __nullable * __nullable)error;

@property (nonatomic, readonly, nonnull) NSURL *url;
@property (nonatomic, readonly) VLCMediaState state;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) BOOL parsed;
@property (nonatomic, readonly, nonnull) NSArray<VLCMediaTrack*>* tracks;
@property (nonatomic, readonly) NSSize videoSize;

- (void)parse;
- (void)parse:(BOOL)async;
- (nonnull NSString *)debugDescription;

@end

@interface VLCMedia (ImageCapture)

- (void)generatePreviewImageFor:(NSArray<NSNumber*>* __nonnull)time
               completionHander:(void (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler;

- (void)generatePreviewImageAt:(NSTimeInterval)start
              completionHander:(void (^ __nonnull)(__nullable CGImageRef image,  NSError* __nullable error))handler;

- (void)generatePreviewImagesAtStart:(NSTimeInterval)start
                                 end:(NSTimeInterval)end
                               count:(NSInteger)count
                    completionHander:(void (^ __nonnull)(NSArray* __nullable images, NSError* __nullable error))handler;

@end