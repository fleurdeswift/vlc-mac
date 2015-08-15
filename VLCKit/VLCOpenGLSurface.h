//
//  VLCOpenGLSurface.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>
#import <GLKit/GLKit.h>

#import "VLCIOSurface.h"

extern NSString *IOSurfaceConfigured;
extern NSString *IOSurfaceChanged;

@interface VLCOpenGLSurface : NSObject <VLCIOSurface>
- (void)render;
@end

@interface VLCOpenGLGlobal : NSObject
@property (weak) NSOpenGLContext *sharedGL;

+ (NSOpenGLContext*)sharedContext;
@end
