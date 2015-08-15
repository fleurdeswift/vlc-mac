//
//  VLCOpenGL.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>

@interface VLCOpenGL : NSObject
@property (readonly) GLuint program;

- (void)setupWithIOSurface:(IOSurfaceRef)ioSurface andCGLContext:(CGLContextObj)context;
- (void)render;
@end
