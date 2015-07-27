//
//  VLCView.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCView.h"

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>
#import <OpenGL/CGLIOSurface.h>
#import <GLKit/GLKit.h>

#import "VLCMediaPlayer.h"
#import "VLCMediaPlayer+Private.h"

#if USE_OPENGL_ES
#   define GLSL_VERSION "100"
#   define PRECISION "precision highp float;"
#else
#   define GLSL_VERSION "150"
#   define PRECISION ""
#endif

static const GLfloat identity[] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

static void GLcheck() {
    GLenum err = glGetError();
    
    if (err) {
        NSString* desc;
    
        switch (err) {
        case GL_INVALID_ENUM:
            desc = @"OpenGL error GL_INVALID_ENUM";
            break;
        case GL_INVALID_OPERATION:
            desc = @"OpenGL error GL_INVALID_OPERATION";
            break;
        default:
            desc = [NSString stringWithFormat:@"OpenGL error %x", (int)err];
            break;
        }
        
        [[NSException exceptionWithName:@"GL" reason:desc userInfo:nil] raise];
    }
}

#define GL_CHECK(m, ...) m(__VA_ARGS__); GLcheck();

static void VerifyShader(GLuint shader) {
    GLint logLength;
    GLint status;

	glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetShaderInfoLog(shader, logLength, &logLength, log);
		fprintf(stderr, "Shader compile log:\n%s", log);
		free(log);
	}

	glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
	if (status == 0) {
        [[NSException exceptionWithName:@"GL" reason:@"Fail to compile shader" userInfo:nil] raise];
	}
}

static void VerifyProgram(GLuint program) {
    GLint logLength;
    GLint status;

	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(program, logLength, &logLength, log);
		fprintf(stderr, "Shader compile log:\n%s", log);
		free(log);
	}

	glGetProgramiv(program, GL_LINK_STATUS, &status);
	if (status == 0) {
        [[NSException exceptionWithName:@"GL" reason:@"Fail to compile shader" userInfo:nil] raise];
	}
}

static GLuint BuildVertexShader(size_t planes)
{
    const char *vertexShader = NULL;

    /* Basic vertex shader */
    vertexShader =
        "#version " GLSL_VERSION "\n"
        PRECISION
        "uniform mat4 mvp;"
        "in      vec2 VertexPosition;"
        "in      vec2 MultiTexCoord0;"
        "out     vec2 TexCoord0;"

        "void main() {"
        " TexCoord0   = MultiTexCoord0;"
        " gl_Position = mvp * vec4(VertexPosition, 0.0, 1.0);"
        "}";

    GLuint shader = glCreateShader(GL_VERTEX_SHADER);
    
    GL_CHECK(glShaderSource,  shader, 1, &vertexShader, NULL);
    GL_CHECK(glCompileShader, shader);
    
    VerifyShader(shader);
    return shader;
}

static GLuint BuildYUVShader(size_t planes)
{
   const char *pixelShader =
        "#version " GLSL_VERSION "\n"
        PRECISION
        "uniform sampler2DRect Texture0;\n"
        "uniform sampler2DRect Texture1;\n"
        "uniform sampler2DRect Texture2;\n"
        "uniform vec4          Coefficient[4];\n"
        "in      vec2          TexCoord0;\n"
        "out     vec4          FragColor;\n"

        "void main(void) {\n"
        " vec4 x,y,z,result;\n"
        " x  = vec4(vec3(texture(Texture0, TexCoord0).r), 1);\n"
        " y  = vec4(vec3(texture(Texture1, TexCoord0).r), 1);\n"
        " z  = vec4(vec3(texture(Texture2, TexCoord0).r), 1);\n"

        " result    =  x * Coefficient[0]  + Coefficient[3];\n"
        " result    = (y * Coefficient[1]) + result;\n"
        " FragColor = (z * Coefficient[2]) + result;\n"
        "}";

    GLuint shader = glCreateShader(GL_FRAGMENT_SHADER);
    
    GL_CHECK(glShaderSource,  shader, 1, &pixelShader, NULL);
    GL_CHECK(glCompileShader, shader);
    
    VerifyShader(shader);
    return shader;
}

static void BuildCoefficientTable(size_t height, float rangeCorrection, GLfloat* values) {
    static const float matrix_bt601_tv2full[12] = {
        1.164383561643836,  0.0000,             1.596026785714286, -0.874202217873451 ,
        1.164383561643836, -0.391762290094914, -0.812967647237771,  0.531667823499146 ,
        1.164383561643836,  2.017232142857142,  0.0000,            -1.085630789302022 ,
    };
    
    static const float matrix_bt709_tv2full[12] = {
        1.164383561643836,  0.0000,             1.792741071428571, -0.972945075016308 ,
        1.164383561643836, -0.21324861427373,  -0.532909328559444,  0.301482665475862 ,
        1.164383561643836,  2.112401785714286,  0.0000,            -1.133402217873451 ,
    };
    
    const float *matrix = height > 576 ? matrix_bt709_tv2full: matrix_bt601_tv2full;

    for (int i = 0; i < 4; i++) {
        float correction = i < 3? rangeCorrection: 1.f;
        
        for (int j = 0; j < 4; j++) {
            values[i * 4 + j] = j < 3 ? correction * matrix[j * 4 + i]: 0.f;
        }
    }
}

@interface VLCOpenGLView : NSOpenGLView <VLCIOSurface>
@end

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
}

- (instancetype)initWithFrame:(NSRect)rect {
    NSOpenGLPixelFormatAttribute attribs[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize,     24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,//NSOpenGLProfileVersion3_2Core,
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

- (void)drawRect:(NSRect)theRect
{
    [[self openGLContext] makeCurrentContext];
    
    if (_boundsChanged) {
        CGRect bounds = self.bounds;
        
        GL_CHECK(glViewport, 0, 0, (GLint)bounds.size.width, (GLint)bounds.size.height);
        _boundsChanged = NO;
    }

    GL_CHECK(glClearColor, 0.5, 0, 0, 0);
    GL_CHECK(glClear, GL_COLOR_BUFFER_BIT);
    if (_ioSurface == NULL) {
        [[self openGLContext] flushBuffer];
        return;
    }
    
    [self render];
	[[self openGLContext] flushBuffer];
}

- (void)render {
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
            CGLError error;
            
            for (GLsizei index = 0; index < _textureCount; index++) {
                GLsizei height = (GLsizei)IOSurfaceGetHeightOfPlane(ioSurface, index);
                GLsizei width  = (GLsizei)IOSurfaceGetWidthOfPlane (ioSurface, index);
                
                GL_CHECK(glBindTexture, GL_TEXTURE_RECTANGLE, _textures[index]);

                error = CGLTexImageIOSurface2D(context, GL_TEXTURE_RECTANGLE, GL_RED, width, height, GL_RED, GL_UNSIGNED_BYTE, ioSurface, index);
                
                if (error != kCGLNoError) {
                    [NSException exceptionWithName:@"CGL" reason:[NSString stringWithFormat:@"CoreGL error %x", error] userInfo:nil];
                }
                
                GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                GL_CHECK(glTexParameteri, GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            }
            
            _vertexShader   = BuildVertexShader(_textureCount);
            _fragmentShader = BuildYUVShader(_textureCount);
            _program        = glCreateProgram();
            
            GL_CHECK(glAttachShader, _program, _vertexShader);
            GL_CHECK(glAttachShader, _program, _fragmentShader);
            GL_CHECK(glLinkProgram, _program);
            VerifyProgram(_program);
            
            GL_CHECK(glUseProgram, _program);
            
            if (_textureCount == 3) {
                GLfloat values[16];
            
                BuildCoefficientTable(IOSurfaceGetHeightOfPlane(ioSurface, 0), 1.0, values);
            
                GL_CHECK(glUniform4fv, glGetUniformLocation(_program, "Coefficient"), 4, values);
                GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture0"), 0);
                GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture1"), 1);
                GL_CHECK(glUniform1i,  glGetUniformLocation(_program, "Texture2"), 2);
            }
            else if (_textureCount == 1) {
                GL_CHECK(glUniform1i, glGetUniformLocation(_program, "Texture0"), 0);
            }
            
            GL_CHECK(glUniformMatrix4fv, glGetUniformLocation(_program, "mvp"), 1, GL_FALSE, identity);

            static GLfloat quad[] = {
                //x, y            s, t
                -1.0f, -1.0f,     0.0f, 0.0f,
                 1.0f, -1.0f,     1280.0f, 0.0f,
                -1.0f,  1.0f,     0.0f, 720.0f,
                 1.0f,  1.0f,     1280.0f, 720.0f
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
        }
    });
}

- (void)ioSurfaceChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.needsDisplay = YES;
    });
}

@end

@implementation VLCView {
    VLCOpenGLView *_opengl;
}

- (instancetype)initWithFrame:(NSRect)rect {
    self = [super initWithFrame:rect];
    
    if (!self) {
        return nil;
    }
    
    _opengl = [[VLCOpenGLView alloc] initWithFrame:NSMakeRect(0, 0, rect.size.width, rect.size.height)];
    [self addSubview:_opengl];
    return self;
}

- (instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if (!self) {
        return nil;
    }
    
    _opengl = [[VLCOpenGLView alloc] initWithFrame:self.bounds];
    
    [self addSubview:_opengl];
    return self;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [_opengl setFrame:self.bounds];
}

- (void)setMediaPlayer:(VLCMediaPlayer *)mediaPlayer {
    if (_mediaPlayer == mediaPlayer)
        return;

    _mediaPlayer = mediaPlayer;
    
    CFTypeRef surface = (__bridge CFTypeRef)_opengl;
    
    libvlc_media_player_set_nsobject(mediaPlayer.impl, (void*)surface);
}

@end
