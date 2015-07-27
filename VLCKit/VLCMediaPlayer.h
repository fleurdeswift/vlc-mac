//
//  VLCMediaPlayer.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VLCMedia;

@interface VLCMediaPlayer : NSObject
- (nullable instancetype)initWithMedia:(nonnull VLCMedia*)media error:(out NSError * __nullable * __nullable)error;

@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly, nullable) VLCMedia* media;

- (void)play;

@end
