//
//  VLCMedia.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMedia.h"
#import "VLCMedia+Private.h"

#import "VLC.h"
#import "VLC+Private.h"

static NSMapTable* mediaTable;

@implementation VLCMedia {
    libvlc_media_t* _media;
}

- (instancetype)initWithPath:(NSString*)filePath withVLC:(VLC*)vlc error:(NSError**)error {
    _media = libvlc_media_new_path(vlc.impl, filePath.fileSystemRepresentation);
    
    if (_media == NULL) {
        reportError(error);
        return nil;
    }
    
    [self _cache];
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

@end

@implementation VLCMedia (Private)

- (libvlc_media_t*)impl {
    return _media;
}

- (instancetype)initWithImplementation:(libvlc_media_t*)impl {
    _media = impl;
    [self _cache];
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
