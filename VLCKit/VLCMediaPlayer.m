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

#import <vlc/libvlc_events.h>

NSString *VLCMediaPlayerStateChanged    = @"VLCMediaPlayerStateChanged";
NSString *VLCMediaPlayerPositionChanged = @"VLCMediaPlayerPositionChanged";
NSString *VLCMediaPlayerTimeChanged     = @"VLCMediaPlayerTimeChanged";
NSString *VLCMediaPlayerMediaChanged    = @"VLCMediaPlayerMediaChanged";

@implementation VLCMediaPlayer {
    libvlc_media_player_t* _player;
}

- (nullable instancetype)initWithMedia:(nonnull VLCMedia*)media error:(NSError**)error {
    _player = libvlc_media_player_new_from_media(media.impl);
    
    if (_player == NULL) {
        reportError(error);
        return nil;
    }

    [self setupEvents];
    return self;
}

- (nullable instancetype)initWithMedias:(nonnull NSArray<VLCMedia*>*)medias error:(out NSError * __nullable * __nullable)error
{
    if (medias.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
        }

        return nil;
    }

    if (medias.count == 1) {
        return [self initWithMedia:medias[0] error: error];
    }

    return (VLCMediaPlayer*)[[VLCMediaPlayerGroup alloc] initWithMedias:medias error:error];
}

- (void)dealloc {
    [self clearEvents];
    libvlc_media_player_release(_player);
}

static void HandleMediaInstanceStateChanged(const libvlc_event_t* event, void* self) {
    VLCMediaPlayer* media = (__bridge VLCMediaPlayer*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [media _stateChanged];
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaPlayerStateChanged object:media];
    });
}

static void HandleMediaPositionChanged(const libvlc_event_t* event, void* self) {
    VLCMediaPlayer* media = (__bridge VLCMediaPlayer*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaPlayerPositionChanged object:media];
    });
}

static void HandleMediaTimeChanged(const libvlc_event_t* event, void* self) {
    VLCMediaPlayer* media = (__bridge VLCMediaPlayer*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaPlayerTimeChanged object:media];
    });
}

static void HandleMediaPlayerMediaChanged(const libvlc_event_t* event, void* self) {
    VLCMediaPlayer* media = (__bridge VLCMediaPlayer*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaPlayerMediaChanged object:media];
    });
}

- (void)setupEvents {
    libvlc_event_manager_t * p_em = libvlc_media_player_event_manager(_player);

    if (p_em) {
        libvlc_event_attach(p_em, libvlc_MediaPlayerPlaying,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerPaused,           HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerEncounteredError, HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerEndReached,       HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerStopped,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerOpening,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerBuffering,        HandleMediaInstanceStateChanged, (__bridge void *)(self));

        libvlc_event_attach(p_em, libvlc_MediaPlayerPositionChanged,  HandleMediaPositionChanged,      (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerTimeChanged,      HandleMediaTimeChanged,          (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaPlayerMediaChanged,     HandleMediaPlayerMediaChanged,   (__bridge void *)(self));
    }
}

- (void)clearEvents {
    libvlc_event_manager_t * p_em = libvlc_media_player_event_manager(_player);

    if (p_em) {
        libvlc_event_detach(p_em, libvlc_MediaPlayerPlaying,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerPaused,           HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerEncounteredError, HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerEndReached,       HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerStopped,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerOpening,          HandleMediaInstanceStateChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerBuffering,        HandleMediaInstanceStateChanged, (__bridge void *)(self));

        libvlc_event_detach(p_em, libvlc_MediaPlayerPositionChanged,  HandleMediaPositionChanged,      (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerTimeChanged,      HandleMediaTimeChanged,          (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaPlayerMediaChanged,     HandleMediaPlayerMediaChanged,   (__bridge void *)(self));
    }
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
    return libvlc_media_player_get_state(_player) == libvlc_Paused;
}

- (void)setPaused:(BOOL)paused {
    libvlc_media_player_set_pause(_player, paused);
}

- (VLCMediaPlayerState)state {
    return (VLCMediaPlayerState)libvlc_media_player_get_state(_player);
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

- (void)setTime:(NSTimeInterval)newTime completionBlock:(void (^)(VLCMediaPlayer* mediaPlayer, NSTimeInterval time))block {
    {
        VLCMediaPlayerState state = self.state;

        if ((state != VLCMediaPlayerStatePlaying) || (state != VLCMediaPlayerStatePaused)) {
            [self play];
        }
    }

    self.time = newTime;

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), NSEC_PER_MSEC, NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        NSTimeInterval time = self.time;
    
        if (time > newTime) {
            block(self, time);
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

@end

@implementation VLCMediaPlayer (Audio)

- (void)setMute:(BOOL)mute {
    libvlc_audio_set_mute(_player, mute);
}

- (void)setAudioModule:(NSString* __nonnull)audioModule {
    libvlc_audio_output_set(_player, audioModule.fileSystemRepresentation);
}

@end

@implementation VLCMediaPlayer (Private)

- (libvlc_media_player_t*)impl {
    return _player;
}

- (void)_stateChanged {
}

@end

@implementation VLCMediaPlayerGroup {
    NSArray<VLCMedia*>* _medias;
    NSInteger           _index;
    NSTimeInterval*     _times;
    NSTimeInterval      _duration;
}

- (nullable instancetype)initWithMedias:(nonnull NSArray<VLCMedia*>*)medias error:(out NSError * __nullable * __nullable)error
{
    if (!(self = [super initWithMedia:medias[0] error:error]))
        return nil;

    _medias   = medias;
    _times    = (NSTimeInterval*)malloc(sizeof(*_times) * _medias.count);
    _duration = 0;

    NSInteger index = 0;

    for (VLCMedia* media in _medias) {
        if (!media.parsed) {
            [media parse];
        }

        NSInteger d = media.duration;

        _duration      += d;
        _times[index++] = d;
    }

    return self;
}

- (void)dealloc {
    free(_times);
}

- (NSTimeInterval)duration {
    return _duration;
}

- (float)position {
    return self.time / _duration;
}

- (void)setPosition:(float)newPosition {
    self.time = newPosition * _duration;
}

- (NSTimeInterval)time {
    NSTimeInterval current = [super time];

    for (NSInteger index = 0; index < _index; index++) {
        current += _times[index];
    }

    return current;
}

- (void)setTime:(NSTimeInterval)newTime {
    if (newTime <= 0) {
        if (_index != 0) {
            _index = 0;
            libvlc_media_player_set_media(self.impl, _medias[0].impl);
        }

        libvlc_media_player_set_time(self.impl, 0);
        return;
    }

    NSTimeInterval current = 0;
    NSInteger      index   = 0;

    for (VLCMedia* media in _medias) {
        NSTimeInterval next = current + _times[index];

        if (next > newTime) {
            _index = index;
            libvlc_media_player_set_media(self.impl, media.impl);
            [super setTime:newTime - current];
        }

        current = next;
        index++;
    }
}

@end
