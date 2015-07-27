//
//  VLCIOSurface.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

@protocol VLCIOSurface
@property (nonatomic, assign) IOSurfaceRef ioSurface;
- (void)ioSurfaceChanged;
@end
