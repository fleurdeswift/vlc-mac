//
//  YUV.m
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "YUV.h"

void BuildYUVCoefficientTable(size_t height, float rangeCorrection, float* values) {
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
