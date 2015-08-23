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
    self.wantsLayer                       = YES;
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

@end
