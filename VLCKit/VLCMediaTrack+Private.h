//
//  VLCMediaTrack+Private.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#include "VLCMediaTrack.h"

#include <vlc/libvlc.h>
#include <vlc/libvlc_media.h>

@interface VLCMediaTrack (Private)
- (instancetype)initWithTrack:(libvlc_media_track_t*)track;

+ (VLCMediaTrack*)track:(libvlc_media_track_t*)track;
@end
