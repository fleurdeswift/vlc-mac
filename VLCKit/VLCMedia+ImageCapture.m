//
//  VLCMedia+ImageCapture.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMedia.h"
#import "VLCMedia+Private.h"

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"

#import "VLC.h"
#import "VLC+Private.h"
#import "VLCIOSurface.h"
#import "VLCOpenGLView.h"

#import "VLCOpenGLSurface.h"
#import "VLCOpenGLShader.h"

static const GLfloat ymirror[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, -1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

static void dataFree(void* context, const void* data, size_t length) {
    free((void*)data);
}

@interface VLCMediaCapture : VLCOpenGLSurface
@end

@implementation VLCMediaCapture {
    GLuint framebuffer;
    GLuint outputTexture;
    GLint  width;
    GLint  height;

    NSOpenGLContext *sharedContext;
    NSOpenGLContext *context;

    VLCMediaPlayer *mediaPlayer;

    NSTimeInterval (^completionHander)(__nullable CGImageRef image, NSError* __nullable error);

    NSInteger frame;
    NSInteger lastFrameCaptured;
}

- (instancetype)initWithTimeAt:(NSTimeInterval)time media:(VLCMedia*)media completionHandler:(NSTimeInterval (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    if (!media.parsed) {
        [media parse];
    }

    NSError* error = nil;

    VLCMediaPlayer* mp = [[VLCMediaPlayer alloc] initWithMedia:media error:&error];

    if (mp == nil) {
        handler(nil, error);
        return nil;
    }

    return [self initWithTimeAt:time size:media.videoSize mediaPlayer:mp completionHandler:handler];
}

- (instancetype)initWithTimeAt:(NSTimeInterval)time size:(NSSize)size mediaPlayer:(VLCMediaPlayer* __nonnull)mp completionHandler:(NSTimeInterval (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    self = [super init];
    if (!self) {
        return nil;
    }

    mediaPlayer      = mp;
    completionHander = handler;

    [mediaPlayer setAudioModule:@"adummy"];

    CFTypeRef surfaceCT = (__bridge CFTypeRef)self;
    
    libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surfaceCT);
    
    [mediaPlayer play];

    if (!mediaPlayer.seekable) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTSUP userInfo:@{
            NSLocalizedDescriptionKey: @"Media isn't seekable"
        }]);

        return nil;
    }

    sharedContext = VLCOpenGLGlobal.sharedContext;
    context       = [[NSOpenGLContext alloc] initWithFormat:sharedContext.pixelFormat shareContext:sharedContext];

    [context makeCurrentContext];

    width  = (GLint)size.width;
    height = (GLint)size.height;
    
    GL_CHECK(glGenFramebuffers, 1, &framebuffer);
    GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
    
    GL_CHECK(glGenTextures, 1, &outputTexture);
    GL_CHECK(glBindTexture, GL_TEXTURE_2D, outputTexture);
    GL_CHECK(glTexImage2D,  GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
    
    GL_CHECK(glFramebufferTexture, GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, outputTexture, 0);
    GL_CHECK(glDrawBuffer, GL_COLOR_ATTACHMENT0);
    GL_CHECK(glReadBuffer, GL_COLOR_ATTACHMENT0);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        return nil;
    
    GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
    GL_CHECK(glViewport, 0, 0, width, height);

    [NSOpenGLContext clearCurrentContext];

    [self seek:time];
    return self;
}

- (void)dealloc {
    [mediaPlayer stop];

    [context makeCurrentContext];
    GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, 0);
    GL_CHECK(glDeleteFramebuffers, 1, &framebuffer);
    GL_CHECK(glDeleteTextures, 1, &outputTexture);
    [NSOpenGLContext clearCurrentContext];
}

- (void)clean {
    [mediaPlayer stop];
    mediaPlayer = nil;
}

- (void)seek:(NSTimeInterval)time {
    VLCMediaCapture *weakSelf = self;

    [mediaPlayer setTime:time completionBlock:^(VLCMediaPlayer* player, NSTimeInterval time){
        [weakSelf seekDone:time];
    }];
}

- (void)capture {
    lastFrameCaptured = frame;

    @try {
        [context makeCurrentContext];

        GL_CHECK(glClearColor, 0, 0, 0, 1);
        GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
        GLint mvp = glGetUniformLocation(self.program, "mvp");
    
        GL_CHECK(glUseProgram, self.program);
        GL_CHECK(glUniformMatrix4fv, mvp, 1, GL_FALSE, ymirror);

        [self render];

        NSInteger dataLength = width * height * 4;
        GLubyte*  data       = (GLubyte*)malloc(dataLength * sizeof(GLubyte));

        GL_CHECK(glReadPixels, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data);

        [NSOpenGLContext clearCurrentContext];

        CGDataProviderRef dataRef    = CGDataProviderCreateWithData(NULL, data, dataLength, dataFree);
        CGColorSpaceRef   colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef        image      = CGImageCreate(width, height, 8, 32, width * 4, colorspace, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, dataRef, NULL, true, kCGRenderingIntentDefault);

        CGDataProviderRelease(dataRef);
        CGColorSpaceRelease(colorspace);

        NSTimeInterval nextTime = -1;

        @try {
            nextTime = completionHander(image, nil);
        }
        @finally {
            CGImageRelease(image);

            if (nextTime < 0) {
                completionHander(nil, nil);
                [self clean];
                return;
            }
            
            NSTimeInterval duration = mediaPlayer.duration - 0.01;
            
            if (nextTime > duration) {
                nextTime = duration;
            }

            [self seek:nextTime];
        }
    }
    @catch (NSError *error) {
        completionHander(nil, error);
        [self clean];
    }
    @catch (id) {
        completionHander(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        [self clean];
    }
}

- (void)ioSurfaceChanged {
    [super ioSurfaceChanged];
    frame++;
}

- (void)seekDone:(NSTimeInterval)time {
    if (time < 0) {
        // Error seeking...
        completionHander(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        [self clean];
        return;
    }

    if (self.ioSurface) {
        if (frame == lastFrameCaptured) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [self seekDone:time];
            });

            return;
        }

        [self capture];
    }
    else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [self seekDone:time];
        });
    }
}

@end

@implementation VLCMedia (ImageCapture)

- (void)generatePreviewImageFor:(NSArray<NSNumber*>*)time
              completionHandler:(void (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    if (time.count == 0) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        return;
    }

    NSTimeInterval             first     = [time firstObject].doubleValue;
    NSMutableArray<NSNumber*>* remaining = [time mutableCopy];

    [remaining removeObjectAtIndex:0];
    [self generatePreviewImageAt:first completionHandler:^(CGImageRef image, NSError* error) {
        handler(image, error);

        if (remaining.count == 0) {
            return (NSTimeInterval)-1;
        }

        NSTimeInterval nextTime = [remaining firstObject].doubleValue;

        [remaining removeObjectAtIndex:0];
        return nextTime;
    }];
}

+ (void)generatePreviewImageAt:(NSTimeInterval)start
                          size:(NSSize)size
                      inMedias:(NSArray<VLCMedia*>* __nonnull)medias
             completionHandler:(NSTimeInterval (^ __nonnull)(__nullable CGImageRef image,  NSError* __nullable error))handler {
    NSError*        error;
    VLCMediaPlayer* mediaPlayer = [[VLCMediaPlayer alloc] initWithMedias:medias error:&error];

    if (error != nil) {
        handler(nil, error);
        return;
    }

    for (VLCMedia* media in medias) {
        if (!media.parsed) {
            [media parse];
        }
    }

    [[[VLCMediaCapture alloc] initWithTimeAt:start size:size mediaPlayer:mediaPlayer completionHandler:handler] description];
}

- (void)generatePreviewImageAt:(NSTimeInterval)time
             completionHandler:(NSTimeInterval (^ __nonnull)(__nullable CGImageRef image, NSError* __nullable error))handler {
    [[[VLCMediaCapture alloc] initWithTimeAt:time media:self completionHandler:handler] description];
}

- (NSArray<NSNumber*>*)timesForStart:(NSTimeInterval)start end:(NSTimeInterval)end count:(NSInteger)count {
    NSTimeInterval duration = self.duration - 0.01;
    
    if (start < 0) {
        return [NSArray array];
    }
    
    if (end > duration) {
        end = duration;

        if (end > (60 * 20)) {
            // For video longer than 20 minutes, we intentionally skip the
            // last two minutes if we can.
            end -= (60 * 2);

            if (start > end) {
                end = duration;
            }
        }
    }
    
    if (start > end) {
        return [NSArray array];
    }
    
    NSTimeInterval             length  = (end - start) / (NSTimeInterval)(count + 2);
    NSMutableArray<NSNumber*>* times   = [NSMutableArray array];
    NSTimeInterval             current = start + length;
    
    for (NSInteger index = 0; index < count; ++index, current += length) {
        [times addObject:@(current)];
    }

    return [times copy];
}

- (NSArray<NSNumber*>* __nonnull)times:(NSInteger)count {
    return [self timesForStart:0 end:FLT_MAX count:count];
}

- (void)generatePreviewImagesAtStart:(NSTimeInterval)start
                                 end:(NSTimeInterval)end
                               count:(NSInteger)count
                   completionHandler:(void (^ __nonnull)(NSArray* __nullable images, NSError* __nullable error))handler {
    NSArray<NSNumber*>* times = [self timesForStart:start end:end count:count];

    if (times.count == 0) {
        handler(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil]);
        return;
    }
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:count];
    
    [self generatePreviewImageFor:times completionHandler:^(CGImageRef image, NSError* error) {
        if (image != NULL) {
            [results addObject:(__bridge id)image];
        }
        else {
            handler(results, error);
        }
    }];
}

@end

