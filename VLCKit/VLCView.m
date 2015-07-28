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
    id <VLCIOSurface> _surface;
}

- (instancetype)initWithFrame:(NSRect)rect {
    self = [super initWithFrame:rect];
    
    if (!self) {
        return nil;
    }
    
    VLCOpenGLView* surface = [[VLCOpenGLView alloc] initWithFrame:NSMakeRect(0, 0, rect.size.width, rect.size.height)];
    
    _surface = surface;
    [self addSubview:surface];
    return self;
}

- (instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if (!self) {
        return nil;
    }
    
    NSRect bounds = self.bounds;
    VLCOpenGLView* surface = [[VLCOpenGLView alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, bounds.size.height)];
    
    _surface = surface;
    [self addSubview:surface];
    return self;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [(NSView*)_surface setFrame:self.bounds];
}

- (void)setMediaPlayer:(VLCMediaPlayer *)mediaPlayer {
    if (_mediaPlayer == mediaPlayer)
        return;

    _mediaPlayer = mediaPlayer;
    
    CFTypeRef surface = (__bridge CFTypeRef)_surface;
    
    libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surface);
}

@end
