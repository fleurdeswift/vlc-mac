//
//  VLCView.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "VLCIOSurface.h"

@class VLCMediaPlayer;

@interface VLCView : NSView

@property (nonatomic, retain) VLCMediaPlayer* mediaPlayer;

@end
