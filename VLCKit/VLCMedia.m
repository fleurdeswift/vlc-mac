//
//  VLCMedia.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMedia.h"
#import "VLCMedia+Private.h"
#import "VLCMediaTrack.h"
#import "VLCMediaTrack+Private.h"

#import "VLC.h"
#import "VLC+Private.h"

#import <vlc/libvlc_events.h>

NSString* VLCMediaMetaChanged     = @"VLCMediaMetaChanged";
NSString* VLCMediaDurationChanged = @"VLCMediaDurationChanged";
NSString* VLCMediaStateChanged    = @"VLCMediaStateChanged";
NSString* VLCMediaSubItemAdded    = @"VLCMediaSubItemAdded";
NSString* VLCMediaParsedChanged   = @"VLCMediaParsedChanged";

static NSMapTable* mediaTable;

@implementation VLCMedia {
    libvlc_media_t* _media;
}

static void HandleMediaMetaChanged(const libvlc_event_t* event, void* self) {
    VLCMedia* media = (__bridge VLCMedia*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaMetaChanged object:media];
    });
}

static void HandleMediaDurationChanged(const libvlc_event_t* event, void* self) {
    VLCMedia* media = (__bridge VLCMedia*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaDurationChanged object:media];
    });
}

static void HandleMediaStateChanged(const libvlc_event_t* event, void* self) {
    VLCMedia* media = (__bridge VLCMedia*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaStateChanged object:media];
    });
}

static void HandleMediaSubItemAdded(const libvlc_event_t* event, void* self) {
    VLCMedia* media = (__bridge VLCMedia*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaSubItemAdded object:media];
    });
}

static void HandleMediaParsedChanged(const libvlc_event_t* event, void* self) {
    VLCMedia* media = (__bridge VLCMedia*)self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaParsedChanged object:media];
    });
}

- (void)setupEvents {
    libvlc_event_manager_t * p_em = libvlc_media_event_manager(_media);

    if (p_em) {
        libvlc_event_attach(p_em, libvlc_MediaMetaChanged,     HandleMediaMetaChanged,     (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaDurationChanged, HandleMediaDurationChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaStateChanged,    HandleMediaStateChanged,    (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaSubItemAdded,    HandleMediaSubItemAdded,    (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaParsedChanged,   HandleMediaParsedChanged,   (__bridge void *)(self));
    }
}

- (void)cancelEvents {
    libvlc_event_manager_t * p_em = libvlc_media_event_manager(_media);

    if (p_em) {
        libvlc_event_detach(p_em, libvlc_MediaMetaChanged,     HandleMediaMetaChanged,     (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaDurationChanged, HandleMediaDurationChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaStateChanged,    HandleMediaStateChanged,    (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaSubItemAdded,    HandleMediaSubItemAdded,    (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaParsedChanged,   HandleMediaParsedChanged,   (__bridge void *)(self));
    }
}

- (instancetype)initWithPath:(NSString*)filePath withVLC:(VLC*)vlc error:(NSError**)error {
    _media = libvlc_media_new_path(vlc.impl, filePath.fileSystemRepresentation);
    
    if (_media == NULL) {
        reportError(error);
        return nil;
    }
    
    [self _cache];
    [self setupEvents];
    return self;
}

- (NSURL *)url {
    return [NSURL URLWithString:[NSString stringWithUTF8String:libvlc_media_get_mrl(_media)]];
}

- (VLCMediaState)state {
    return (VLCMediaState)libvlc_media_get_state(_media);
}

- (NSTimeInterval)duration {
    libvlc_time_t duration = libvlc_media_get_duration(_media);
    
    if (duration < 0) {
        return duration;
    }

    return duration / 1000.0;
}

- (BOOL)parsed {
    return libvlc_media_is_parsed(_media)? YES: NO;
}

- (void)dealloc {
    [self cancelEvents];
    libvlc_media_release(_media);
}

- (void)parse {
    libvlc_media_parse(_media);
}

- (void)parse:(BOOL)async {
    if (async) {
        libvlc_media_parse_async(_media);
    }
    else {
        libvlc_media_parse(_media);
    }
}

- (NSString *)debugDescription {
    if (!self.parsed) {
        return @{
            @"url":    self.url,
            @"parsed": @(self.parsed)
        }.description;
    }
    else {
        return @{
            @"url":      self.url,
            @"parsed":   @(self.parsed),
            @"duration": @(self.duration)
        }.description;
    }
}

- (NSArray<VLCMediaTrack*>*)tracks {
    libvlc_media_track_t** vtracks = NULL;
    int                    trackCount = libvlc_media_tracks_get(_media, &vtracks);
    NSMutableArray*        results    = [NSMutableArray array];

    for (int index = 0; index < trackCount; index++) {
        [results addObject:[[VLCMediaTrack alloc] initWithTrack:vtracks[index]]];
    }

    libvlc_media_tracks_release(vtracks, trackCount);
    return results;
}

- (NSSize)videoSize {
    libvlc_media_track_t** vtracks = NULL;
    int                    trackCount = libvlc_media_tracks_get(_media, &vtracks);

    for (int index = 0; index < trackCount; index++) {
        if (vtracks[index]->i_type == libvlc_track_video) {
            NSSize s = NSMakeSize(vtracks[index]->video->i_width, vtracks[index]->video->i_height);

            libvlc_media_tracks_release(vtracks, trackCount);
            return s;
        }
    }

    libvlc_media_tracks_release(vtracks, trackCount);
    return NSZeroSize;
}

@end

@implementation VLCMedia (Private)

- (libvlc_media_t*)impl {
    return _media;
}

- (instancetype)initWithImplementation:(libvlc_media_t*)impl {
    _media = impl;
    [self _cache];
    [self setupEvents];
    return self;
}

- (void)_cache {
    if (mediaTable == NULL) {
        mediaTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsIntegerPersonality |NSPointerFunctionsOpaqueMemory
                                                valueOptions:NSPointerFunctionsWeakMemory
                                                    capacity:1];
    }
    
    [mediaTable setObject:self forKey:(__bridge id)_media];
}

+ (VLCMedia*)mediaForImplementation:(libvlc_media_t*)impl {
    if (mediaTable) {
        VLCMedia *media = [mediaTable objectForKey:(__bridge id)impl];
        
        if (media) {
            return media;
        }
    }

    return [[VLCMedia alloc] initWithImplementation:impl];
}

@end
