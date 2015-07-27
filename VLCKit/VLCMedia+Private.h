//
//  VLCMedia+Private.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLCMedia.h"

#include <vlc/libvlc.h>
#include <vlc/libvlc_media.h>

@interface VLCMedia (Private)
@property (assign, readonly, nonatomic) libvlc_media_t* impl;

- (instancetype)initWithImplementation:(libvlc_media_t*)impl;
+ (VLCMedia*)mediaForImplementation:(libvlc_media_t*)impl;
- (void)_cache;
@end
