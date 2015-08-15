//
//  VLCOpenGLView.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLView.h"
#import "VLCOpenGLShader.h"

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>
#import <OpenGL/CGLIOSurface.h>
#import <GLKit/GLKit.h>

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"
#import "YUV.h"

static const GLfloat identity[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

static const GLfloat ymirror[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, -1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

@implementation VLCOpenGLView {
    IOSurfaceRef _ioSurface;
    GLsizei      _textureCount;
    GLuint       _textures[8];
    GLuint       _quadVAOId;
    GLuint       _quadVBOId;
    GLuint       _vertexShader;
    GLuint       _fragmentShader;
    GLuint       _program;
    BOOL         _boundsChanged;
    
    void (^_nextFrameCapture)(CGImageRef frame);
}

- (instancetype)initWithFrame:(NSRect)rect {
    NSOpenGLPixelFormatAttribute attribs[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize,     24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };

    NSOpenGLPixelFormat *pixelAttribs = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];

    _boundsChanged = YES;
    self = [super initWithFrame:rect pixelFormat:pixelAttribs];
    self.wantsBestResolutionOpenGLSurface = YES;
    return self;
}

- (void)reshape {
    [super reshape];
    _boundsChanged = YES;
}

- (void)update {
    [super update];
    _boundsChanged = YES;
}

- (void)_updateViewport {
    CGRect bounds = [self convertRectToBacking:[self bounds]];
    GL_CHECK(glViewport, 0, 0, (GLint)bounds.size.width, (GLint)bounds.size.height);
    _boundsChanged = NO;
}

- (void)drawRect:(NSRect)theRect
{
    [[self openGLContext] makeCurrentContext];
    
    if (_boundsChanged) {
        [self _updateViewport];
    }

    if (_ioSurface == NULL) {
        GL_CHECK(glClearColor, 0, 0, 0, 1);
        GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
        [[self openGLContext] flushBuffer];
        return;
    }
    
    [self render];
    [[self openGLContext] flushBuffer];
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

- (BOOL)isOpaque {
    return YES;
}

- (IOSurfaceRef)ioSurface {
    return _ioSurface;
}

- (void)setIoSurface:(IOSurfaceRef)ioSurface {
    if (ioSurface) {
        IOSurfaceIncrementUseCount(ioSurface);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSOpenGLContext* contextNS = [self openGLContext];
        
        [contextNS makeCurrentContext];
        
        if (_ioSurface) {
            IOSurfaceDecrementUseCount(_ioSurface);
        }
        
        if (_textureCount) {
            glDeleteTextures(_textureCount, _textures);
            glDeleteShader(_vertexShader);
            glDeleteShader(_fragmentShader);
            glDeleteProgram(_program);
            memset(_textures, 0, sizeof(_textures));
        }

        _ioSurface = ioSurface;
    
        if (ioSurface) {
            _textureCount = (GLuint)IOSurfaceGetPlaneCount(ioSurface);
            GL_CHECK(glGenTextures, _textureCount, _textures);

            CGLContextObj context = (CGLContextObj)[contextNS CGLContextObj];
            CGLError      error;
            
            OSType pixelFormat    = IOSurfaceGetPixelFormat(ioSurface);
            GLint  internalFormat = GL_RED;
            GLint  format         = GL_RED;
            GLint  type           = GL_UNSIGNED_BYTE;
            BOOL   rgb            = _textureCount == 1;
            
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
            
            self.needsDisplay = YES;
            [self invalidateIntrinsicContentSize];
            [[self superview] invalidateIntrinsicContentSize];
        }
    });
}

- (NSSize)intrinsicContentSize {
    if (_ioSurface == nil) {
        return NSMakeSize(320, 200);
    }
    
    NSSize size = NSMakeSize(IOSurfaceGetWidth(_ioSurface), IOSurfaceGetHeight(_ioSurface));
    return [self convertSizeFromBacking:size];
}

- (void)ioSurfaceChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.needsDisplay = YES;
        [self displayIfNeededIgnoringOpacity];
        
        if (_nextFrameCapture) {
            NSOpenGLContext* contextNS = [self openGLContext];
        
            [contextNS makeCurrentContext];
            
            GLuint framebuffer;
            GLuint outputTexture;
            GLint  width  = (GLint)IOSurfaceGetWidth(self.ioSurface);
            GLint  height = (GLint)IOSurfaceGetHeight(self.ioSurface);
            
            GL_CHECK(glGenFramebuffers, 1, &framebuffer);
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
            
            GL_CHECK(glGenTextures, 1, &outputTexture);
            GL_CHECK(glBindTexture, GL_TEXTURE_2D, outputTexture);
            GL_CHECK(glTexImage2D,  GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
            
            GL_CHECK(glFramebufferTexture, GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, outputTexture, 0);
            GL_CHECK(glDrawBuffer, GL_COLOR_ATTACHMENT0);
            GL_CHECK(glReadBuffer, GL_COLOR_ATTACHMENT0);
            
            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
                return;
            
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, framebuffer);
            GL_CHECK(glViewport, 0, 0, width, height);
            GL_CHECK(glClearColor, 1, 0, 0, 1);
            GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
            
            GLint mvp = glGetUniformLocation(_program, "mvp");
            
            GL_CHECK(glUniformMatrix4fv, mvp, 1, GL_FALSE, ymirror);
            [self render];
            GL_CHECK(glUniformMatrix4fv, mvp, 1, GL_FALSE, identity);
            [self _updateViewport];
            
            NSInteger dataLength = width * height * 4;
            GLubyte*  data       = (GLubyte*)malloc(dataLength * sizeof(GLubyte));

            GL_CHECK(glReadPixels, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data);
            GL_CHECK(glBindFramebuffer, GL_FRAMEBUFFER, 0);
            GL_CHECK(glDeleteFramebuffers, 1, &framebuffer);
            GL_CHECK(glDeleteTextures, 1, &outputTexture);

            CGDataProviderRef dataRef    = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
            CGColorSpaceRef   colorspace = CGColorSpaceCreateDeviceRGB();
            CGImageRef        image      = CGImageCreate(width, height, 8, 32, width * 4, colorspace, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, dataRef, NULL, true, kCGRenderingIntentDefault);
            
            void (^nextFrameCapture)(CGImageRef image) = _nextFrameCapture;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @try {
                    nextFrameCapture(image);
                }
                @finally {
                    CGImageRelease(image);
                }
            });
            
            _nextFrameCapture = nil;
            CGDataProviderRelease(dataRef);
            CGColorSpaceRelease(colorspace);
        }
    });
}

- (void)captureNextFrame:(void (^)(CGImageRef frame))captureBlock {
    dispatch_async(dispatch_get_main_queue(), ^{
        _nextFrameCapture = captureBlock;
    });
}

@end
