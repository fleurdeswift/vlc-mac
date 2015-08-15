//
//  VLCOpenGLShader.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCOpenGLShader.h"

#if USE_OPENGL_ES
#   define GLSL_VERSION "100"
#   define PRECISION "precision highp float;"
#else
#   define GLSL_VERSION "150"
#   define PRECISION ""
#endif

void GLcheck() {
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
        case GL_INVALID_VALUE:
            desc = @"OpenGL error GL_INVALID_VALUE";
            break;
        default:
            desc = [NSString stringWithFormat:@"OpenGL error %x", (int)err];
            break;
        }
        
        [[NSException exceptionWithName:@"GL" reason:desc userInfo:nil] raise];
    }
}

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

void VerifyProgram(GLuint program) {
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

GLuint BuildVertexShader(size_t planes)
{
    const char *vertexShader = NULL;

    /* Basic vertex shader */
    if (planes == 3) {
        vertexShader =
            "#version " GLSL_VERSION "\n"
            PRECISION
            "uniform mat4 mvp;\n"
            "uniform vec2 TexSize0;\n"
            "uniform vec2 TexSize1;\n"
            "uniform vec2 TexSize2;\n"
            "in      vec2 VertexPosition;\n"
            "in      vec2 MultiTexCoord0;\n"
            "out     vec2 TexCoord0;\n"
            "out     vec2 TexCoord1;\n"
            "out     vec2 TexCoord2;\n"

            "void main() {\n"
            " TexCoord0   = MultiTexCoord0 * TexSize0;\n"
            " TexCoord1   = MultiTexCoord0 * TexSize1;\n"
            " TexCoord2   = MultiTexCoord0 * TexSize2;\n"
            " gl_Position = mvp * vec4(VertexPosition, 0.0, 1.0);\n"
            "}";
    }
    else {
        vertexShader =
            "#version " GLSL_VERSION "\n"
            PRECISION
            "uniform mat4 mvp;\n"
            "uniform vec2 TexSize0;\n"
            "in      vec2 VertexPosition;\n"
            "in      vec2 MultiTexCoord0;\n"
            "out     vec2 TexCoord0;\n"

            "void main() {\n"
            " TexCoord0   = MultiTexCoord0 * TexSize0;\n"
            " gl_Position = mvp * vec4(VertexPosition, 0.0, 1.0);\n"
            "}";
    }

    GLuint shader = glCreateShader(GL_VERTEX_SHADER);
    
    GL_CHECK(glShaderSource,  shader, 1, &vertexShader, NULL);
    GL_CHECK(glCompileShader, shader);
    
    VerifyShader(shader);
    return shader;
}

GLuint BuildRGBAShader(size_t planes) {
   const char *pixelShader =
        "#version " GLSL_VERSION "\n"
        PRECISION
        "uniform sampler2DRect Texture0;\n"
        "in      vec2          TexCoord0;\n"
        "out     vec4          FragColor;\n"

        "void main(void) {\n"
        " FragColor = texture(Texture0, TexCoord0);\n"
        "}";

    GLuint shader = glCreateShader(GL_FRAGMENT_SHADER);
    
    GL_CHECK(glShaderSource,  shader, 1, &pixelShader, NULL);
    GL_CHECK(glCompileShader, shader);
    
    VerifyShader(shader);
    return shader;
}

GLuint BuildYUVShader(size_t planes)
{
   const char *pixelShader =
        "#version " GLSL_VERSION "\n"
        PRECISION
        "uniform sampler2DRect Texture0;\n"
        "uniform sampler2DRect Texture1;\n"
        "uniform sampler2DRect Texture2;\n"
        "uniform vec4          Coefficient[4];\n"
        "in      vec2          TexCoord0;\n"
        "in      vec2          TexCoord1;\n"
        "in      vec2          TexCoord2;\n"
        "out     vec4          FragColor;\n"

        "void main(void) {\n"
        " vec4 x,y,z,result;\n"
        " x  = vec4(vec3(texture(Texture0, TexCoord0).r), 1);\n"
        " y  = vec4(vec3(texture(Texture1, TexCoord1).r), 1);\n"
        " z  = vec4(vec3(texture(Texture2, TexCoord2).r), 1);\n"

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
