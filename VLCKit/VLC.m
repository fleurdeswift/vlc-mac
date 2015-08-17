//
//  VLC.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLC.h"
#import "VLC+Private.h"

#include <vlc/libvlc_media.h>
#include <vlc/libvlc_media_player.h>

static void LogData(void *data, int level, const libvlc_log_t *ctx, const char *fmt, va_list args) {
    fprintf(stderr, fmt, args);
}

@implementation VLC {
    libvlc_instance_t* _vlc;
}

- (instancetype)init:(NSError**)error {
    const char* args[] = {
        "--no-color",
        "--vout=iosurface",
        NULL
    };

    _vlc = libvlc_new(2, args);
    
    if (_vlc == NULL) {
        reportError(error);
        return NULL;
    }
    
    libvlc_log_set(_vlc, LogData, NULL);
    return self;
}

- (instancetype)initWithArguments:(NSArray<NSString*> *)arguments error:(NSError**)error {
    NSMutableArray<NSString*> *moded = [arguments mutableCopy];

    BOOL hasNoColor = NO;
    BOOL hasVout    = NO;

    for (NSString *arg in arguments) {
        if ([arg isEqualToString:@"--no-color"]) {
            hasNoColor = YES;
        }
        else if ([arg isEqualToString:@"--vout="]) {
            hasVout = YES;
        }
    }

    if (!hasNoColor) {
        [moded addObject:@"--no-color"];
    }

    if (!hasVout) {
        [moded addObject:@"--vout=iosurface"];
    }

    int argc = (int)moded.count;
    
    if (argc) {
        const char** args = (const char**)alloca(sizeof(char*) * moded.count);

        for (int index = 0; index < argc; index++) {
            args[index] = moded[index].fileSystemRepresentation;
        }

        _vlc = libvlc_new(argc, args);
    }
    else {
        _vlc = libvlc_new(0, NULL);
    }
    
    if (_vlc == NULL) {
        reportError(error);
        return nil;
    }
    
    return self;
}

- (void)dealloc {
    libvlc_release(_vlc);
}

+ (NSString*)lastError {
    const char* err = libvlc_errmsg();
    
    if (err == NULL) {
        return nil;
    }

    NSString* errorAsString = [[NSString alloc] initWithUTF8String:err];
    
    libvlc_clearerr();
    return errorAsString;
}

- (NSDictionary<NSString*,NSString*>*)audioModules {
    libvlc_audio_output_t* first   = libvlc_audio_output_list_get(_vlc);
    libvlc_audio_output_t* current = first;
    NSMutableDictionary*   modules = [NSMutableDictionary dictionary];
    
    for (; current; current = current->p_next) {
        modules[@(current->psz_name)] = @(current->psz_description);
    }
    
    libvlc_audio_output_list_release(first);
    return modules;
}

@end

@implementation VLC (Private)

- (libvlc_instance_t*)impl {
    return _vlc;
}

@end

void reportError(NSError** error) {
    if (error == NULL) {
        return;
    }

    NSString* errorString = [VLC lastError];
    
    if (errorString == NULL) {
        errorString = @"Unknown error";
    }
    
    *error = [NSError errorWithDomain:@"VLC" code:1 userInfo:@{
        NSLocalizedDescriptionKey: errorString
    }];
}
