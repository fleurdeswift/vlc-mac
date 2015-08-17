//
//  VLCMediaTrack.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, VLCTrackType) {
    VLCTrackTypeUnknown,
    VLCTrackTypeVideo,
    VLCTrackTypeAudio,
    VLCTrackTypeText,
};

@interface VLCMediaTrack : NSObject
@property (nonatomic, readonly) NSInteger trackID;
@property (nonatomic, readonly) VLCTrackType trackType;

@property (nonatomic, readonly) unsigned int codecID;
@property (nonatomic, readonly) NSInteger codecProfile;
@property (nonatomic, readonly) NSInteger codecLevel;
@property (nonatomic, readonly, nullable) NSString* codecName;
@property (nonatomic, readonly) NSInteger bitrate;

@property (nonatomic, readonly, nullable) NSString* trackDescription;
@property (nonatomic, readonly, nullable) NSString* language;
@end

@interface VLCMediaTrackAudio : VLCMediaTrack
@property (nonatomic, readonly) NSInteger channels;
@property (nonatomic, readonly) NSInteger sampleRate;
@end

@interface VLCMediaTrackVideo : VLCMediaTrack
@property (nonatomic, readonly) NSSize size;
@property (nonatomic, readonly) NSInteger sourceAspectRatioNum;
@property (nonatomic, readonly) NSInteger sourceAspectRatioDen;
@property (nonatomic, readonly) NSInteger frameRateNum;
@property (nonatomic, readonly) NSInteger frameRateDen;
@end
