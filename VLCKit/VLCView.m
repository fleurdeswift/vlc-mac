//
//  VLCView.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCView.h"

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"
#import "VLCOpenGLView.h"

@implementation VLCView {
}

- (void)_setupSurfaceView {
    NSRect         bounds  = self.bounds;

    VLCOpenGLView* surfaceView = [[VLCOpenGLView alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, bounds.size.height)];

    _surface         = surfaceView.surface;
    _surfaceView     = surfaceView;
    _backgroundColor = nil;
    [self addSubview:surfaceView];
}

- (void)setSurface:(id <VLCIOSurface>)surface {
    if (_surface == surface) {
        return;
    }

    _surface             = surface;
    _surfaceView.surface = surface;
}

- (instancetype)initWithFrame:(NSRect)rect {
    self = [super initWithFrame:rect];
    
    if (!self) {
        return nil;
    }
    
    [self _setupSurfaceView];
    return self;
}

- (instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if (!self) {
        return nil;
    }
    
    [self _setupSurfaceView];
    return self;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];

    NSView* surface = ((NSView *)_surfaceView);
    NSRect  surfaceRect;
    NSSize  size    = surface.intrinsicContentSize;
    CGFloat ratio   = size.width       / size.height;
    CGFloat ratioW  = frame.size.width / frame.size.height;
    
    if (ratio >= ratioW) {
        surfaceRect.size.height = frame.size.width * (1.0f / ratio);
        surfaceRect.origin.y    = (frame.size.height - surfaceRect.size.height) / 2.0f;

        surfaceRect.origin.x    = 0;
        surfaceRect.size.width  = frame.size.width;
    }
    else {
        surfaceRect.size.width  = frame.size.height * ratio;
        surfaceRect.origin.x    = (frame.size.width - surfaceRect.size.width) / 2.0f;

        surfaceRect.origin.y    = 0;
        surfaceRect.size.height = frame.size.height;
    }
    
    surfaceRect.origin.x    = floor(surfaceRect.origin.x);
    surfaceRect.origin.y    = floor(surfaceRect.origin.y);
    surfaceRect.size.width  = ceil(surfaceRect.size.width);
    surfaceRect.size.height = ceil(surfaceRect.size.height);
    [surface setFrame:surfaceRect];
}

- (void)setMediaPlayer:(VLCMediaPlayer *)mediaPlayer {
    if (_mediaPlayer == mediaPlayer)
        return;

    _mediaPlayer = mediaPlayer;

    CFTypeRef surface = (CFTypeRef)libvlc_media_player_get_nsobject(mediaPlayer.impl);

    if (surface) {
        self.surface = (__bridge id <VLCIOSurface>)surface;
    }
    else {
        VLCOpenGLSurface* newSurface = [[VLCOpenGLSurface alloc] init];

        surface = (__bridge CFTypeRef)newSurface;
        libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surface);

        self.surface = newSurface;
    }
}

- (NSSize)intrinsicContentSize {
    if (self.preserveInitialSize) {
        return self.bounds.size;
    }

    return ((NSView *)_surfaceView).intrinsicContentSize;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_backgroundColor) {
        [_backgroundColor setFill];
        NSRectFill(dirtyRect);
    }
}

@end
