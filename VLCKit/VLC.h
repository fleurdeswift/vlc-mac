//
//  VLC.h
//  VLCKit
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VLC : NSObject

- (nullable instancetype)init:(out NSError * __nullable * __nullable)error;
- (nullable instancetype)initWithArguments:(nonnull NSArray<NSString*> *)arguments error:(out NSError * __nullable * __nullable)error;

+ (nullable NSString*)lastError;

@property (nonatomic, nonnull, readonly) NSDictionary<NSString*, NSString*>* audioModules;
@end
