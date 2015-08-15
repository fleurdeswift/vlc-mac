//
//  VLCOpenGL.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGL.h"
#import "VLCOpenGLShader.h"
#import "YUV.h"

static const GLfloat identity[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

@implementation VLCOpenGL {
    GLsizei      _textureCount;
    GLuint       _textures[8];
    GLuint       _vertexShader;
    GLuint       _fragmentShader;
    GLuint       _program;
    GLuint       _quadVAOId;
    GLuint       _quadVBOId;
}

- (void)dealloc
{
    if (_quadVAOId) {
        glDeleteVertexArrays(1, &_quadVAOId);
    }

    if (_quadVBOId) {
        glDeleteBuffers(1, &_quadVBOId);
    }
    
    [self freeShaderAndTextures];
}

- (GLuint)program
{
    return _program;
}

- (void)render {
    GL_CHECK(glUseProgram, _program);
    GL_CHECK(glBindVertexArray, _quadVAOId);
    GL_CHECK(glBindBuffer, GL_ARRAY_BUFFER, _quadVBOId);

    for (GLuint i = 0; i < _textureCount; i++) {
        GL_CHECK(glActiveTexture, GL_TEXTURE0 + i);
        GL_CHECK(glBindTexture,   GL_TEXTURE_RECTANGLE, _textures[i]);
    }
    
    GL_CHECK(glEnableVertexAttribArray, glGetAttribLocation(_program, "VertexPosition"));
    GL_CHECK(glEnableVertexAttribArray, glGetAttribLocation(_program, "MultiTexCoord0"));
    GL_CHECK(glDrawArrays, GL_TRIANGLE_STRIP, 0, 4);
}

- (void)freeShaderAndTextures
{
    if (_textureCount) {
        glDeleteTextures(_textureCount, _textures);
        glDeleteShader(_vertexShader);
        glDeleteShader(_fragmentShader);
        glDeleteProgram(_program);
        memset(_textures, 0, sizeof(_textures));
        
        _textureCount   = 0;
        _vertexShader   = 0;
        _fragmentShader = 0;
        _program        = 0;
    }
}

- (void)setupWithIOSurface:(IOSurfaceRef)ioSurface andCGLContext:(CGLContextObj)context {
    [self freeShaderAndTextures];

    if (ioSurface) {
        _textureCount = (GLuint)IOSurfaceGetPlaneCount(ioSurface);
        GL_CHECK(glGenTextures, _textureCount, _textures);

        CGLError error;
        OSType   pixelFormat    = IOSurfaceGetPixelFormat(ioSurface);
        GLint    internalFormat = GL_RED;
        GLint    format         = GL_RED;
        GLint    type           = GL_UNSIGNED_BYTE;
        BOOL     rgb            = _textureCount == 1;
        
        switch (pixelFormat) {
        case 'BGRA':
            internalFormat = GL_RGB;
            format         = GL_BGRA;
            type           = GL_UNSIGNED_INT_8_8_8_8_REV;
            break;
            
        default:
            break;
        }
        
        for (GLsizei index = 0; index < _textureCount; index++) {
            GLsizei height = (GLsizei)IOSurfaceGetHeightOfPlane(ioSurface, index);
            GLsizei width  = (GLsizei)IOSurfaceGetWidthOfPlane (ioSurface, index);
            
            GL_CHECK(glBindTexture, GL_TEXTURE_RECTANGLE, _textures[index]);

            error = CGLTexImageIOSurface2D(context, GL_TEXTURE_RECTANGLE, internalFormat, width, height, format, type, ioSurface, index);
            
            if (error != kCGLNoError) {
                [NSException exceptionWithName:@"CGL" reason:[NSString stringWithFormat:@"CoreGL error %x", error] userInfo:nil];
            }
            
            GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        }
        
        _vertexShader = BuildVertexShader(_textureCount);
        
        if (rgb) {
            _fragmentShader = BuildRGBAShader(_textureCount);
        }
        else {
            _fragmentShader = BuildYUVShader(_textureCount);
        }
        
        _program = glCreateProgram();
        GL_CHECK(glAttachShader, _program, _vertexShader);
        GL_CHECK(glAttachShader, _program, _fragmentShader);
        GL_CHECK(glLinkProgram, _program);
        VerifyProgram(_program);
        
        GL_CHECK(glUseProgram, _program);
        
        if (_textureCount == 3) {
            GLfloat   values[16];
            CFTypeRef yuvRangeCorrection = IOSurfaceCopyValue(ioSurface, CFSTR("YUVCorrection"));
            float     yuvRangeCorrectionF;
            
            CFNumberGetValue(yuvRangeCorrection, kCFNumberFloatType, &yuvRangeCorrectionF);
            CFRelease(yuvRangeCorrection);

            BuildYUVCoefficientTable(IOSurfaceGetHeightOfPlane(ioSurface, 0), yuvRangeCorrectionF, values);
        
            GL_CHECK(glUniform4fv, glGetUniformLocation(_program, "Coefficient"), 4, values);
            GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture0"), 0);
            GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture1"), 1);
            GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture2"), 2);
            GL_CHECK(glUniform2f,  glGetUniformLocation(_program, "TexSize0"), IOSurfaceGetWidthOfPlane(ioSurface, 0), IOSurfaceGetHeightOfPlane(ioSurface, 0));
            GL_CHECK(glUniform2f,  glGetUniformLocation(_program, "TexSize1"), IOSurfaceGetWidthOfPlane(ioSurface, 1), IOSurfaceGetHeightOfPlane(ioSurface, 1));
            GL_CHECK(glUniform2f,  glGetUniformLocation(_program, "TexSize2"), IOSurfaceGetWidthOfPlane(ioSurface, 2), IOSurfaceGetHeightOfPlane(ioSurface, 2));
        }
        else if (_textureCount == 1) {
            GL_CHECK(glUniform1i, glGetUniformLocation(_program, "Texture0"), 0);
            GL_CHECK(glUniform2f, glGetUniformLocation(_program, "TexSize0"), IOSurfaceGetWidthOfPlane(ioSurface, 0), IOSurfaceGetHeightOfPlane(ioSurface, 0));
        }
        
        GL_CHECK(glUniformMatrix4fv, glGetUniformLocation(_program, "mvp"), 1, GL_FALSE, identity);

        static const GLfloat quad[] = {
            // x, y           s, t
            -1.0f, -1.0f,     0.0f, 1.0f,
             1.0f, -1.0f,     1.0f, 1.0f,
            -1.0f,  1.0f,     0.0f, 0.0f,
             1.0f,  1.0f,     1.0f, 0.0f
        };
        
        if (_quadVAOId == 0) {
            glGenVertexArrays(1, &_quadVAOId);
            glGenBuffers     (1, &_quadVBOId);
        }
        
        GL_CHECK(glBindVertexArray, _quadVAOId);
        GL_CHECK(glBindBuffer, GL_ARRAY_BUFFER, _quadVBOId);
        GL_CHECK(glBufferData, GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
        GL_CHECK(glVertexAttribPointer, glGetAttribLocation(_program, "VertexPosition"), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), NULL);
        GL_CHECK(glVertexAttribPointer, glGetAttribLocation(_program, "MultiTexCoord0"), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (const GLvoid*)(2 * sizeof(GLfloat)));
    }
}

@end
