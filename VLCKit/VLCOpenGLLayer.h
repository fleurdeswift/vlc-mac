//
//  VLCOpenGLLayer.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "VLCIOSurfaceView.h"
#import "VLCOpenGLSurface.h"

@interface VLCOpenGLLayer : CAOpenGLLayer <VLCIOSurfaceView>
@property (nonatomic, retain) VLCOpenGLSurface* surface;
@end
