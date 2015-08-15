//
//  VLCOpenGLView.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLView.h"

#import "VLCOpenGLSurface.h"
#import "VLCOpenGLShader.h"

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>
#import <OpenGL/CGLIOSurface.h>
#import <GLKit/GLKit.h>

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"
#import "YUV.h"

#if 0
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
#endif

@implementation VLCOpenGLView {
    BOOL             _boundsChanged;
    NSOpenGLContext* _sharedContext;
}

- (instancetype)initWithFrame:(NSRect)rect {
    _sharedContext = VLCOpenGLGlobal.sharedContext;
    _boundsChanged = YES;

    self                                  = [super initWithFrame:rect pixelFormat:_sharedContext.pixelFormat];
    self.openGLContext                    = [[NSOpenGLContext alloc] initWithFormat:_sharedContext.pixelFormat shareContext:_sharedContext];
    self.wantsBestResolutionOpenGLSurface = YES;
    return self;
}

- (void)setSurface:(VLCOpenGLSurface *)surface
{
    if (_surface == surface) {
        return;
    }

    if (_surface) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_surface];
    }
    
    _surface       = surface;
    _boundsChanged = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ioSurfaceConfigured:) name:IOSurfaceConfigured object:_surface];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ioSurfaceChanged:)    name:IOSurfaceChanged    object:_surface];

    self.needsDisplay = YES;
    [self invalidateIntrinsicContentSize];
    [[self superview] invalidateIntrinsicContentSize];
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
    NSOpenGLContext *context = self.openGLContext;

    [context makeCurrentContext];
    
    if (_boundsChanged) {
        [self _updateViewport];
    }

    if (_surface == nil) {
        GL_CHECK(glClearColor, 0, 0, 0, 1);
        GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
        [context flushBuffer];
        return;
    }
    
    [_surface render];
    [context flushBuffer];
}

- (BOOL)isOpaque {
    return YES;
}

- (NSSize)intrinsicContentSize {
    if ((_surface == nil) || (_surface.ioSurface == NULL)) {
        return NSMakeSize(320, 200);
    }

    IOSurfaceRef surface = _surface.ioSurface;
    NSSize       size    = NSMakeSize(IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface));
    
    return [self convertSizeFromBacking:size];
}

- (void)ioSurfaceConfigured:(id)sender {
    self.needsDisplay = YES;
    [self invalidateIntrinsicContentSize];
    [[self superview] invalidateIntrinsicContentSize];
}

- (void)ioSurfaceChanged:(id)sender {
    self.needsDisplay = YES;
    [self displayIfNeededIgnoringOpacity];
}

#if 0
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

#endif

@end
