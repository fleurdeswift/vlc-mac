//
//  VLCMediaPlayer.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"

#import "VLC.h"
#import "VLC+Private.h"
#import "VLCMedia.h"
#import "VLCMedia+Private.h"

@implementation VLCMediaPlayer {
    libvlc_media_player_t* _player;
}

- (nullable instancetype)initWithMedia:(nonnull VLCMedia*)media error:(NSError**)error {
    _player = libvlc_media_player_new_from_media(media.impl);
    
    if (_player == NULL) {
        reportError(error);
        return nil;
    }
    
    return self;
}

- (void)dealloc {
    libvlc_media_player_release(_player);
}

- (BOOL)playing {
    return libvlc_media_player_is_playing(_player)? YES: NO;
}

- (VLCMedia*)media {
    return [VLCMedia mediaForImplementation:libvlc_media_player_get_media(_player)];
}

- (void)play {
    libvlc_media_player_play(_player);
}

- (void)stop {
    libvlc_media_player_stop(_player);
}

- (void)pause {
    libvlc_media_player_pause(_player);
}

- (BOOL)paused {
    return !self.paused;
}

- (void)setPaused:(BOOL)paused {
    libvlc_media_player_set_pause(_player, paused);
}

- (NSTimeInterval)duration {
    return libvlc_media_player_get_length(_player) / 1000.0f;
}

- (NSTimeInterval)time {
    libvlc_time_t t = libvlc_media_player_get_time(_player);
    
    if (t < 0) {
        return -1;
    }

    return t / 1000.0f;
}

- (void)setTime:(NSTimeInterval)newTime completionBlock:(dispatch_block_t)block {
    libvlc_media_player_set_time(_player, (libvlc_time_t)(newTime * 1000));

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), NSEC_PER_MSEC, NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        if (self.time >= newTime) {
            block();
            dispatch_source_cancel(timer);
        }
    });
    
    dispatch_resume(timer);
}

- (void)setTime:(NSTimeInterval)newTime {
    libvlc_media_player_set_time(_player, (libvlc_time_t)(newTime * 1000));
}

- (float)position {
    return libvlc_media_player_get_position(_player);
}

- (void)setPosition:(float)newPosition {
    libvlc_media_player_set_position(_player, newPosition);
}

- (BOOL)seekable {
    return libvlc_media_player_is_seekable(_player)? true: false;
}

- (BOOL)mute {
    return libvlc_audio_get_mute(_player)? true: false;
}

- (void)setMute:(BOOL)mute {
    libvlc_audio_set_mute(_player, mute);
}

@end

@implementation VLCMediaPlayer (Private)

- (libvlc_media_player_t*)impl {
    return _player;
}

@end
