//
//  VLCMediaPlayer.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VLCMedia;

@interface VLCMediaPlayer : NSObject
- (nullable instancetype)initWithMedia:(nonnull VLCMedia*)media error:(out NSError * __nullable * __nullable)error;

@property (nonatomic, readonly, nullable) VLCMedia* media;

@property (nonatomic, readonly) BOOL playing;
@property (nonatomic) BOOL paused;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval time;
@property (nonatomic) float position;
@property (nonatomic, readonly) BOOL seekable;

- (void)play;
- (void)stop;
- (void)pause;

- (void)setTime:(NSTimeInterval)newTime completionBlock:(__nonnull void (^)(__nonnull VLCMediaPlayer*  mediaPlayer, NSTimeInterval time))block;
@end

@interface VLCMediaPlayer (Audio)
@property (nonatomic) BOOL mute;
- (void)setAudioModule:(NSString* __nonnull)audioModule;
@end
