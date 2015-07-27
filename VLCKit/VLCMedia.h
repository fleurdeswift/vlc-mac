//
//  VLCMedia.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VLC;

typedef NS_ENUM(NSInteger, VLCMediaState) {
    VLCMediaStateNothingSpecial = 0,
    VLCMediaStateOpening,
    VLCMediaStateBuffering,
    VLCMediaStatePlaying,
    VLCMediaStatePaused,
    VLCMediaStateStopped,
    VLCMediaStateEnded,
    VLCMediaStateError
};

@interface VLCMedia : NSObject
- (nullable instancetype)initWithPath:(nonnull NSString*)filePath withVLC:(nonnull VLC*)vlc error:(out NSError * __nullable * __nullable)error;

@property (nonatomic, readonly, nonnull) NSURL *url;
@property (nonatomic, readonly) VLCMediaState state;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) BOOL parsed;

- (void)parse;
- (void)parse:(BOOL)async;
- (nonnull NSString *)debugDescription;
@end
