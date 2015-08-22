//
//  VLCMediaTrack.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMediaTrack.h"
#import "VLCMediaTrack+Private.h"

enum es_format_category_e
{
    UNKNOWN_ES = 0x00,
    VIDEO_ES,
    AUDIO_ES,
    SPU_ES,
    NAV_ES,
};

extern const char * vlc_fourcc_GetDescription( int i_cat, unsigned int i_fourcc );

@implementation VLCMediaTrack

- (NSString *)codecName
{
    int track_type = UNKNOWN_ES;

    if (_trackType == VLCTrackTypeAudio) {
        track_type = AUDIO_ES;
    }
    else if (_trackType == VLCTrackTypeVideo) {
        track_type = VIDEO_ES;
    }
    else if (_trackType == VLCTrackTypeText) {
        track_type = SPU_ES;
    }

    const char *ret = vlc_fourcc_GetDescription(track_type, _codecID);

    if (ret)
        return [NSString stringWithUTF8String:ret];

    return @"";
}

@end

@implementation VLCMediaTrack (Private)

- (instancetype)initWithTrack:(libvlc_media_track_t*)track {
    _codecID      = track->i_codec;
    _codecProfile = track->i_profile;
    _codecLevel   = track->i_level;
    _trackID      = track->i_id;
    _bitrate      = track->i_bitrate;

    switch (track->i_type) {
    case libvlc_track_audio:
        _trackType = VLCTrackTypeAudio;
        break;

    case libvlc_track_video:
        _trackType = VLCTrackTypeVideo;
        break;

    case libvlc_track_text:
        _trackType = VLCTrackTypeText;
        break;

    case libvlc_track_unknown:
    default:
        _trackType = VLCTrackTypeUnknown;
        break;
    }

    if (track->psz_description) {
        _trackDescription = [[NSString alloc] initWithUTF8String:track->psz_description];
    }

    if (track->psz_language) {
        _language = [[NSString alloc] initWithUTF8String:track->psz_language];
    }

    return self;
}

+ (VLCMediaTrack*)track:(libvlc_media_track_t*)track {
    switch (track->i_type) {
    case libvlc_track_audio:
        return [[VLCMediaTrackAudio alloc] initWithTrack:track];
    case libvlc_track_video:
        return [[VLCMediaTrackVideo alloc] initWithTrack:track];
    default:
        return [[VLCMediaTrack alloc] initWithTrack:track];
    }
}

- (NSString *)description {
    NSString *cn = self.codecName;

    if (cn) {
        return cn;
    }

    return @"Unknown Codec";
}

@end

@implementation VLCMediaTrackAudio

- (instancetype)initWithTrack:(libvlc_media_track_t*)track {
    self = [super initWithTrack:track];
    _channels   = track->audio->i_channels;
    _sampleRate = track->audio->i_rate;
    return self;
}

@end

@implementation VLCMediaTrackVideo

- (instancetype)initWithTrack:(libvlc_media_track_t*)track {
    self = [super initWithTrack:track];
    _size                 = NSMakeSize(track->video->i_width, track->video->i_height);
    _sourceAspectRatioNum = track->video->i_sar_num;
    _sourceAspectRatioDen = track->video->i_sar_den;
    _frameRateNum         = track->video->i_frame_rate_num;
    _frameRateDen         = track->video->i_frame_rate_den;
    return self;
}

@end
