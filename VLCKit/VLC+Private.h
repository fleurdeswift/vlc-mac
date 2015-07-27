//
//  VLC+Private.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import "VLC.h"

#include <vlc/libvlc.h>

@interface VLC (Private)
@property (assign, readonly, nonatomic) libvlc_instance_t* impl;
@end

void reportError(NSError** error);
