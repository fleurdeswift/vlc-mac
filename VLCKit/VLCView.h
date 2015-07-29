//
//  VLCView.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class VLCMediaPlayer;
@protocol VLCIOSurface;

@interface VLCView : NSView
@property (nonatomic, retain) VLCMediaPlayer* mediaPlayer;
@property (nonatomic, retain) NSColor *backgroundColor;
@property (nonatomic, retain, readonly) id <VLCIOSurface> surface;
@end
