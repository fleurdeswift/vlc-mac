//
//  VLCIOSurfaceView.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

@protocol VLCIOSurface;

@protocol VLCIOSurfaceView
@property (nonatomic, retain) id <VLCIOSurface> surface;
@end
