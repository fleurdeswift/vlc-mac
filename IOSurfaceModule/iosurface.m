/*****************************************************************************
 * iosurface.c: IOSurface based video output display method for OSX/iOS
 *****************************************************************************
 * Copyright (C) 2000-2015 VLC authors and VideoLAN
 *
 * Authors: Fleur-de-Swift <fleurdeswift@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import <Foundation/Foundation.h>

#define MODULE_STRING "iosurface"
#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_vout_display.h>

#include <CoreFoundation/CoreFoundation.h>

#define picture_pool_Release picture_pool_Delete
#define N_(s) s

#define IOSURFACE_TEXT N_("IOSurface video output")
#define IOSURFACE_LONGTEXT N_( \
    "IOSurface video output supporting process isolation concepts of Apple platforms")

static int  Open (vlc_object_t *);
static void Close(vlc_object_t *);

vlc_module_begin ()
    set_shortname( N_("IOSurface") )
    set_description( N_("IOSurface video output") )
    set_capability( "vout display", 0 )
    set_callbacks( Open, Close )
    add_shortcut( "iosurface" )

    set_category( CAT_VIDEO )
    set_subcategory( SUBCAT_VIDEO_VOUT )
vlc_module_end ()

@protocol VLCIOSurface
@property (nonatomic, assign) IOSurfaceRef ioSurface;
- (void)ioSurfaceChanged;
@end

@interface VLCIOStorage : NSObject {
@public
    __weak id <VLCIOSurface> surface;
}

@end

@implementation VLCIOStorage
@end

typedef void (*ConvertFunc)(void* dest, const void* src, size_t row, size_t height);

/*****************************************************************************
 * Local prototypes
 *****************************************************************************/
struct vout_display_sys_t {
    picture_pool_t* pool;
    CFTypeRef     storage;
    IOSurfaceRef  surface;
    uint64_t      surface_hash;
    ConvertFunc   convert_func;
};

static picture_pool_t* Pool   (vout_display_t *, unsigned count);
static void            Prepare(vout_display_t *, picture_t *, subpicture_t *);
static void            Display(vout_display_t *, picture_t *, subpicture_t *);
static int             Control(vout_display_t *, int, va_list);

/*****************************************************************************
 * OpenVideo: activates dummy vout display method
 *****************************************************************************/
static int Open(vlc_object_t *object)
{
    vout_display_t *vd = (vout_display_t *)object;
    vout_display_sys_t *sys;

    vd->sys = sys = calloc(1, sizeof(*sys));
    if (!sys)
        return VLC_EGENERIC;
    sys->pool = NULL;

    vd->pool    = Pool;
    vd->prepare = Prepare;
    vd->display = Display;
    vd->control = Control;
    vd->manage  = NULL;

    VLCIOStorage* storage = [[VLCIOStorage alloc] init];

    sys->storage     = CFRetain((__bridge CFTypeRef)storage);
    storage->surface = (__bridge id<VLCIOSurface>)var_InheritAddress(vd, "drawable-nsobject");
    
    vout_display_DeleteWindow(vd, NULL);
    return VLC_SUCCESS;
}

static void Close(vlc_object_t *object)
{
    vout_display_t *vd = (vout_display_t *)object;
    vout_display_sys_t *sys = vd->sys;

    if (sys->pool) {
        picture_pool_Release(sys->pool);
    }
    
    if (sys->surface) {
        IOSurfaceDecrementUseCount(sys->surface);
        sys->surface = NULL;
        sys->surface_hash = 0;
    }
    
    CFRelease(sys->storage);
    free(sys);
}

static picture_pool_t *Pool(vout_display_t *vd, unsigned count)
{
    vout_display_sys_t *sys = vd->sys;
    if (!sys->pool)
        sys->pool = picture_pool_NewFromFormat(&vd->fmt, count);
    return sys->pool;
}

static uint64_t HashPictureFormat(picture_t* picture)
{
    uint64_t n;
    
    n   = ((unsigned short)picture->format.i_height);
    n <<= 16;
    n  |= ((unsigned short)picture->format.i_width);
    n <<= 16;
    n  |= ((unsigned short)picture->i_planes);
    n <<= 3;

    n ^= picture->format.i_chroma;
    return n;
}

static void rgb24_to_bgr32(void* dest, const void* src, size_t row, size_t height) {
    unsigned char* destb = (unsigned char*)dest;
    unsigned char* srcb  = (unsigned char*)src;

    for (size_t y = 0; y < height; y++) {
        size_t x;
    
        for (x = 0; x < row; x += 3, srcb += 3, destb += 4) {
            destb[0] = srcb[2];
            destb[1] = srcb[1];
            destb[2] = srcb[0];
            destb[3] = 0xff;
        }
        
        srcb -= (x - row);
    }
}

static void bgr24_to_bgr32(void* dest, const void* src, size_t row, size_t height) {
    unsigned char* destb = (unsigned char*)dest;
    unsigned char* srcb  = (unsigned char*)src;

    for (size_t y = 0; y < height; y++) {
        size_t x;
    
        for (x = 0; x < row; x += 3, srcb += 3, destb += 4) {
            destb[0] = srcb[0];
            destb[1] = srcb[1];
            destb[2] = srcb[2];
            destb[3] = 0xff;
        }
        
        srcb -= (x - row);
    }
}

static void Prepare(vout_display_t *vd, picture_t *picture, subpicture_t *subpicture)
{
    VLC_UNUSED(subpicture);
    
    vout_display_sys_t *sys = vd->sys;
    
    if (sys == NULL) {
        return;
    }
    
    uint64_t hash = HashPictureFormat(picture);

    if (sys->surface_hash != hash) {
        if (sys->surface) {
            IOSurfaceDecrementUseCount(sys->surface);
            sys->surface = NULL;
            sys->surface_hash = 0;
        }
    
        NSMutableArray *planes = [NSMutableArray arrayWithCapacity:picture->i_planes];

        vlc_fourcc_t fourcc             = picture->format.i_chroma;
        int          divisor            = 1;
        int          multiplicator      = 1;
        float        yuvRangeCorrection = 1.0f;

        sys->convert_func = NULL;
        
        if (vlc_fourcc_IsYUV(fourcc)) {
            const vlc_fourcc_t *list = vlc_fourcc_GetYUVFallback(fourcc);
            
            while (*list) {
                const vlc_chroma_description_t *dsc = vlc_fourcc_GetChromaDescription(*list);
                
                if (dsc && dsc->plane_count == 3 && dsc->pixel_size == 1) {
                    break;
                }
                else if (dsc && dsc->plane_count == 3 && dsc->pixel_size == 2) {
                    yuvRangeCorrection = (float)((1 << 16) - 1) / ((1 << dsc->pixel_bits) - 1);
                    break;
                }
                
                list++;
            }
        }
        else if (fourcc == VLC_CODEC_XYZ12) {
            // Nothing special to. It will be the renderer's job to process that pixel format
            // specificity.
        }
        else {
            if (picture->format.i_bits_per_pixel == 24) {
                // IOSurface is litterally unable to process pixels that aren't memory aligned. 24-bits pixels
                // is never going to work. The CPU will have to perform the translation. The rest can be done
                // directly on the GPU.
                if (fourcc == VLC_CODEC_RGB24) {
                    sys->convert_func = rgb24_to_bgr32;
                }
                else {
                    sys->convert_func = bgr24_to_bgr32;
                }
                
                fourcc        = VLC_CODEC_BGRA;
                divisor       = 3;
                multiplicator = 4;
            }
        }
        
        for (int index = 0; index < picture->i_planes; index++) {
            [planes addObject:@{
                (__bridge NSString*)kIOSurfacePlaneBytesPerElement: @(picture->p[index].i_pixel_pitch / divisor * multiplicator),
                (__bridge NSString*)kIOSurfacePlaneBytesPerRow:     @(picture->p[index].i_pitch       / divisor * multiplicator),
                (__bridge NSString*)kIOSurfacePlaneHeight:          @(picture->p[index].i_visible_lines),
                (__bridge NSString*)kIOSurfacePlaneWidth:           @(picture->p[index].i_visible_pitch / picture->p[index].i_pixel_pitch)
            }];
        }
        
        sys->surface = IOSurfaceCreate((__bridge CFDictionaryRef)@{
            (__bridge NSString*)kIOSurfaceWidth:       @(picture->format.i_width),
            (__bridge NSString*)kIOSurfaceHeight:      @(picture->format.i_height),
            (__bridge NSString*)kIOSurfacePixelFormat: @(CFSwapInt32BigToHost(fourcc)),
            (__bridge NSString*)kIOSurfacePlaneInfo:   planes
        });
        
        if (sys->surface) {
            sys->surface_hash = hash;
            
            IOSurfaceSetValues(sys->surface, (__bridge CFDictionaryRef)@{
                @"AspectRatioNum": @(picture->format.i_sar_num),
                @"AspectRatioDen": @(picture->format.i_sar_den),
                @"YUVCorrection":  @(yuvRangeCorrection)
            });

            VLCIOStorage* storage = (__bridge VLCIOStorage *)sys->storage;
            
            if (storage) {
                id <VLCIOSurface> remoteSurface = storage->surface;
                
                if (remoteSurface) {
                    remoteSurface.ioSurface = sys->surface;
                }
            }
        }
    }

}

static void Display(vout_display_t *vd, picture_t *picture, subpicture_t *subpicture)
{
    VLC_UNUSED(subpicture);
    
    vout_display_sys_t *sys = vd->sys;
    
    if (sys == NULL) {
        picture_Release(picture);
        return;
    }
    
    if (sys->surface) {
        uint32_t seed;
        
        IOSurfaceLock(sys->surface, 0, &seed);
        
        for (int index = 0; index < picture->i_planes; index++) {
            void*  dest   = IOSurfaceGetBaseAddressOfPlane(sys->surface, index);
            size_t row    = IOSurfaceGetBytesPerRowOfPlane(sys->surface, index);
            size_t height = IOSurfaceGetHeightOfPlane(sys->surface, index);
            
            if (sys->convert_func) {
                sys->convert_func(dest, picture->p[index].p_pixels, picture->p[index].i_pitch, height);
            }
            else {
                memcpy(dest, picture->p[index].p_pixels, row * height);
            }
        }
        
        IOSurfaceUnlock(sys->surface, 0, &seed);
        
        VLCIOStorage* storage = (__bridge VLCIOStorage *)sys->storage;
        
        if (storage) {
            id <VLCIOSurface> remoteSurface = storage->surface;
        
            if (remoteSurface) {
                [remoteSurface ioSurfaceChanged];
            }
        }
    }
    
    picture_Release(picture);
}

static int Control(vout_display_t *vd, int query, va_list args)
{
    VLC_UNUSED(vd);
    VLC_UNUSED(query);
    VLC_UNUSED(args);
    return VLC_SUCCESS;
}