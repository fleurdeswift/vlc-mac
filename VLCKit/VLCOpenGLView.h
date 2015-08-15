//
//  VLCOpenGLView.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "VLCOpenGLSurface.h"
#import "VLCView.h"

@interface VLCOpenGLView : NSOpenGLView <VLCIOSurfaceView>
@property (nonatomic, retain) VLCOpenGLSurface* surface;
@end
