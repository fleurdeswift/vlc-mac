//
//  VLCView.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "VLCIOSurfaceView.h"

@class VLCMediaPlayer;

@interface VLCView : NSView <VLCIOSurfaceView>
@property (nonatomic, retain) VLCMediaPlayer* mediaPlayer;
@property (nonatomic, retain) NSColor *backgroundColor;
@property (nonatomic, retain) id <VLCIOSurface> surface;
@property (nonatomic, retain, readonly) id <VLCIOSurfaceView> surfaceView;
@end
