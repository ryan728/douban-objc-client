//
//  DOUService.h
//  DOUAPIEngine
//
//  Created by Lin GUO on 11-11-1.
//  Copyright (c) 2011年 Douban Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DOUHttpRequest.h"
#import "GDataEntryBase.h"
#import "DoubanEntryPhoto.h"


@class ASINetworkQueue;
@interface DOUService : NSObject {
 @private
  ASINetworkQueue   *queue_;  
  NSString          *apiBaseUrlString_;  
  NSString          *clientId_;
  NSString          *clientSecret_;
}

@property (nonatomic, copy) NSString *apiBaseUrlString;
@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *clientSecret;


+ (DOUService *)sharedInstance;

- (BOOL)isValid;

- (void)addRequest:(DOUHttpRequest *)request;


#if NS_BLOCKS_AVAILABLE

- (DOUHttpRequest *)get:(DOUQuery *)query callback:(DOUReqBlock)block;

- (DOUHttpRequest *)post:(DOUQuery *)query callback:(DOUReqBlock)block;

- (DOUHttpRequest *)post:(DOUQuery *)query object:(GDataEntryBase *)object callback:(DOUReqBlock)block;

- (DOUHttpRequest *)post:(DOUQuery *)query 
   photoData:(NSData *)photoData
      format:(NSString *)format
 description:(NSString *)description
    callback:(DOUReqBlock)block;

- (DOUHttpRequest *)delete:(DOUQuery *)query callback:(DOUReqBlock)block;

#endif


- (DOUHttpRequest *)get:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate;

- (DOUHttpRequest *)post:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate;
- (DOUHttpRequest *)put:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate;

- (DOUHttpRequest *)post:(DOUQuery *)query object:(GDataEntryBase *)object delegate:(id<DOUHttpRequestDelegate>)delegate;
- (DOUHttpRequest *)put:(DOUQuery *)query object:(GDataEntryBase *)object delegate:(id<DOUHttpRequestDelegate>)delegate;

- (DOUHttpRequest *)delete:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate;

- (DOUHttpRequest *)put:(DOUQuery *)query object:(GDataEntryBase *)object callback:(DOUReqBlock)block;


@end
