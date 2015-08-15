//
//  VLCOpenGLLayer.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLLayer.h"
#import "VLCOpenGLSurface.h"

@implementation VLCOpenGLLayer {
    NSOpenGLContext* sharedContext;
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

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat
{
    if (sharedContext == nil) {
        sharedContext = VLCOpenGLGlobal.sharedContext;
    }

    CGLContextObj context = NULL;

    CGLCreateContext(pixelFormat, sharedContext.CGLContextObj, &context);
    return context;
}

@end
