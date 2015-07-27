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

@end

@implementation VLCMediaPlayer (Private)

- (libvlc_media_player_t*)impl {
    return _player;
}

@end
