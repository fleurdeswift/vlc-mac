//
//  VLCOpenGLView.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLView.h"

#import "VLCOpenGL.h"
#import "VLCOpenGLShader.h"

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>
#import <OpenGL/CGLIOSurface.h>
#import <GLKit/GLKit.h>

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"
#import "YUV.h"

static const GLfloat identity[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

static const GLfloat ymirror[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, -1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

@implementation VLCOpenGLView {
    IOSurfaceRef     _ioSurface;
    VLCOpenGL*       _gl;
    BOOL             _boundsChanged;
    NSOpenGLContext* _sharedContext;
    
    void (^_nextFrameCapture)(CGImageRef frame);
}

- (instancetype)initWithFrame:(NSRect)rect {
    _sharedContext = VLCOpenGLGlobal.sharedContext;
    _gl            = [[VLCOpenGL alloc] init];
    _boundsChanged = YES;

    self                                  = [super initWithFrame:rect pixelFormat:_sharedContext.pixelFormat];
    self.openGLContext                    = [[NSOpenGLContext alloc] initWithFormat:_sharedContext.pixelFormat shareContext:_sharedContext];
    self.wantsBestResolutionOpenGLSurface = YES;
    return self;
}

- (void)reshape {
    [super reshape];
    _boundsChanged = YES;
}

- (void)update {
    [super update];
    _boundsChanged = YES;
}

- (void)_updateViewport {
    CGRect bounds = [self convertRectToBacking:[self bounds]];
    GL_CHECK(glViewport, 0, 0, (GLint)bounds.size.width, (GLint)bounds.size.height);
    _boundsChanged = NO;
}

- (void)drawRect:(NSRect)theRect
{
    [[self openGLContext] makeCurrentContext];
    
    if (_boundsChanged) {
        [self _updateViewport];
    }

    if (_ioSurface == NULL) {
        GL_CHECK(glClearColor, 0, 0, 0, 1);
        GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
        [[self openGLContext] flushBuffer];
        return;
    }
    
    [_gl render];
    [[self openGLContext] flushBuffer];
}

- (BOOL)isOpaque {
    return YES;
}

- (IOSurfaceRef)ioSurface {
    return _ioSurface;
}

- (void)setIoSurface:(IOSurfaceRef)ioSurface {
    if (ioSurface) {
        IOSurfaceIncrementUseCount(ioSurface);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSOpenGLContext* contextNS = [self openGLContext];
        
        [contextNS makeCurrentContext];
        
        if (_ioSurface) {
            IOSurfaceDecrementUseCount(_ioSurface);
        }
        
        CGLContextObj context = (CGLContextObj)[contextNS CGLContextObj];
        
        _ioSurface = ioSurface;
        [_gl setupWithIOSurface:ioSurface andCGLContext:context];
    
        if (ioSurface) {
            self.needsDisplay = YES;
            [self invalidateIntrinsicContentSize];
            [[self superview] invalidateIntrinsicContentSize];
        }
    });
}

- (NSSize)intrinsicContentSize {
    if (_ioSurface == nil) {
        return NSMakeSize(320, 200);
    }
    
    NSSize size = NSMakeSize(IOSurfaceGetWidth(_ioSurface), IOSurfaceGetHeight(_ioSurface));
    return [self convertSizeFromBacking:size];
}

- (void)ioSurfaceChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.needsDisplay = YES;
        [self displayIfNeededIgnoringOpacity];
        
        if (_nextFrameCapture) {
            NSOpenGLContext* contextNS = [self openGLContext];
        
            [contextNS makeCurrentContext];
            
            GLuint framebuffer;
            GLuint outputTexture;
            GLint  width  = (GLint)IOSurfaceGetWidth(self.ioSurface);
            GLint  height = (GLint)IOSurfaceGetHeight(self.ioSurface);
            
            GL_CHECK(glGenFramebuffers, 1, &framebuffer);
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
            
            GL_CHECK(glGenTextures, 1, &outputTexture);
            GL_CHECK(glBindTexture, GL_TEXTURE_2D, outputTexture);
            GL_CHECK(glTexImage2D,  GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
            
            GL_CHECK(glFramebufferTexture, GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, outputTexture, 0);
            GL_CHECK(glDrawBuffer, GL_COLOR_ATTACHMENT0);
            GL_CHECK(glReadBuffer, GL_COLOR_ATTACHMENT0);
            
            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
                return;
            
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
            GL_CHECK(glViewport, 0, 0, width, height);
            GL_CHECK(glClearColor, 1, 0, 0, 1);
            GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
            
            GLint mvp = glGetUniformLocation(_gl.program, "mvp");
            
            GL_CHECK(glUniformMatrix4fv, mvp, 1, GL_FALSE, ymirror);
            [_gl render];
            GL_CHECK(glUniformMatrix4fv, mvp, 1, GL_FALSE, identity);
            [self _updateViewport];
            
            NSInteger dataLength = width * height * 4;
            GLubyte*  data       = (GLubyte*)malloc(dataLength * sizeof(GLubyte));

            GL_CHECK(glReadPixels, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data);
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, 0);
            GL_CHECK(glDeleteFramebuffers, 1, &framebuffer);
            GL_CHECK(glDeleteTextures, 1, &outputTexture);

            CGDataProviderRef dataRef    = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
            CGColorSpaceRef   colorspace = CGColorSpaceCreateDeviceRGB();
            CGImageRef        image      = CGImageCreate(width, height, 8, 32, width * 4, colorspace, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, dataRef, NULL, true, kCGRenderingIntentDefault);
            
            void (^nextFrameCapture)(CGImageRef image) = _nextFrameCapture;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @try {
                    nextFrameCapture(image);
                }
                @finally {
                    CGImageRelease(image);
                }
            });
            
            _nextFrameCapture = nil;
            CGDataProviderRelease(dataRef);
            CGColorSpaceRelease(colorspace);
        }
    });
}

- (void)captureNextFrame:(void (^)(CGImageRef frame))captureBlock {
    dispatch_async(dispatch_get_main_queue(), ^{
        _nextFrameCapture = captureBlock;
    });
}

@end
