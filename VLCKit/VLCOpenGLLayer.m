//
//  VLCOpenGLLayer.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLLayer.h"

#import "VLCIOSurface.h"
#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"
#import "VLCOpenGLSurface.h"

@implementation VLCOpenGLLayer {
    NSOpenGLContext* sharedContext;
    BOOL             dirty;
}

- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask {
    CGLPixelFormatAttribute attribs[] =  {
        kCGLPFADisplayMask, 0,
        kCGLPFAColorSize,   24,
        kCGLPFAAlphaSize,   8,
        kCGLPFAAccelerated,
        kCGLPFADoubleBuffer,
        kCGLPFAAllowOfflineRenderers,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };

    attribs[1] = mask;

    CGLPixelFormatObj pixFormatObj  = NULL;
    GLint             numPixFormats = 0;

    CGLChoosePixelFormat(attribs, &pixFormatObj, &numPixFormats);
    return pixFormatObj;
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat {
    if (sharedContext == nil) {
        sharedContext = VLCOpenGLGlobal.sharedContext;
    }

    CGLContextObj context = NULL;

    CGLCreateContext(pixelFormat, sharedContext.CGLContextObj, &context);
    return context;
}

- (BOOL)canDrawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp {
    return dirty;
}

- (void)drawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp {
    dirty = NO;

    if (_surface == nil) {
        return;
    }

	CGLSetCurrentContext(glContext);
    [_surface render];
}

- (void)setSurface:(VLCOpenGLSurface *)surface {
    if (_surface == surface) {
        return;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_surface];
    _surface = surface;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ioSurfaceChanged:) name:IOSurfaceConfigured object:_surface];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ioSurfaceChanged:) name:IOSurfaceChanged    object:_surface];
}

- (void)ioSurfaceChanged:(id)sender {
    dirty = YES;
}

- (void)setMediaPlayer:(VLCMediaPlayer *)mediaPlayer {
    if (_mediaPlayer == mediaPlayer)
        return;

    _mediaPlayer = mediaPlayer;

    CFTypeRef surface = (CFTypeRef)libvlc_media_player_get_nsobject(mediaPlayer.impl);

    if (surface) {
        self.surface = (__bridge VLCOpenGLSurface*)surface;
    }
    else {
        VLCOpenGLSurface* newSurface = [[VLCOpenGLSurface alloc] init];

        surface = (__bridge CFTypeRef)newSurface;
        libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surface);

        self.surface = newSurface;
    }
}

@end
