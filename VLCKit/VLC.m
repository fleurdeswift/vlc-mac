//
//  VLC.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLC.h"
#import "VLC+Private.h"

static void LogData(void *data, int level, const libvlc_log_t *ctx, const char *fmt, va_list args) {
    fprintf(stderr, fmt, args);
}

@implementation VLC {
    libvlc_instance_t* _vlc;
}

- (instancetype)init:(NSError**)error {
    _vlc = libvlc_new(0, NULL);
    
    if (_vlc == NULL) {
        reportError(error);
        return NULL;
    }
    
    libvlc_log_set(_vlc, LogData, NULL);
    return self;
}

- (instancetype)initWithArguments:(NSArray<NSString*> *)arguments error:(NSError**)error {
    int argc = (int)arguments.count;
    
    if (argc) {
        const char** args = (const char**)alloca(sizeof(char*) * arguments.count);

        for (int index = 0; index < argc; index++) {
            args[index] = arguments[index].fileSystemRepresentation;
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
