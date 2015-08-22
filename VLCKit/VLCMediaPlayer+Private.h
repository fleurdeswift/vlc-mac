//
//  VLCMediaPlayer+Private.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMediaPlayer.h"

#include <vlc/libvlc.h>
#include <vlc/libvlc_media.h>
#include <vlc/libvlc_media_player.h>

@interface VLCMediaPlayer (Private)
@property (assign, readonly, nonnull, nonatomic) libvlc_media_player_t* impl;

- (void)_stateChanged;

@end

@interface VLCMediaPlayerGroup : VLCMediaPlayer
- (nullable instancetype)initWithMedias:(nonnull NSArray<VLCMedia*>*)medias error:(out NSError * __nullable * __nullable)error;
@end
