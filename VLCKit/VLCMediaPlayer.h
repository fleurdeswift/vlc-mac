//
//  VLCMediaPlayer.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VLCMedia;

extern NSString * __nonnull VLCMediaPlayerStateChanged;
extern NSString * __nonnull VLCMediaPlayerPositionChanged;
extern NSString * __nonnull VLCMediaPlayerTimeChanged;
extern NSString * __nonnull VLCMediaPlayerMediaChanged;

typedef NS_ENUM(NSInteger, VLCMediaPlayerState) {
    VLCMediaPlayerStateUnknown = 0,
    VLCMediaPlayerStateOpening,
    VLCMediaPlayerStateBuffering,
    VLCMediaPlayerStatePlaying,
    VLCMediaPlayerStatePaused,
    VLCMediaPlayerStateStopped,
    VLCMediaPlayerStateEnded,
    VLCMediaPlayerStateError
};

@interface VLCMediaPlayer : NSObject
- (nullable instancetype)initWithMedia:(nonnull VLCMedia*)media error:(out NSError * __nullable * __nullable)error;
- (nullable instancetype)initWithMedias:(nonnull NSArray<VLCMedia*>*)medias error:(out NSError * __nullable * __nullable)error;

@property (nonatomic, readonly, nullable) VLCMedia* media;

@property (nonatomic, readonly) BOOL playing;
@property (nonatomic) BOOL paused;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval time;
@property (nonatomic) float position;
@property (nonatomic, readonly) BOOL seekable;
@property (nonatomic, readonly) VLCMediaPlayerState state;

- (void)play;
- (void)stop;
- (void)pause;

- (void)setTime:(NSTimeInterval)newTime completionBlock:(void (^ __nonnull)(VLCMediaPlayer* __nonnull mediaPlayer, NSTimeInterval time))block;
@end

@interface VLCMediaPlayer (Audio)
@property (nonatomic) BOOL mute;
- (void)setAudioModule:(NSString* __nonnull)audioModule;
@end
