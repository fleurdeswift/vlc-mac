//
//  VLCOpenGLLayer.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "VLCIOSurfaceView.h"
#import "VLCOpenGLSurface.h"

@class VLCMediaPlayer;

@interface VLCOpenGLLayer : CAOpenGLLayer <VLCIOSurfaceView>
@property (nonatomic, retain) VLCOpenGLSurface* surface;
@property (nonatomic, retain) VLCMediaPlayer* mediaPlayer;
@end
