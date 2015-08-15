//
//  VLCOpenGLShader.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>

#define GL_CHECK(m, ...) m(__VA_ARGS__); GLcheck();

GLuint BuildYUVShader(size_t planes);
GLuint BuildRGBAShader(size_t planes);
GLuint BuildVertexShader(size_t planes);

void VerifyProgram(GLuint program);

void GLcheck();
