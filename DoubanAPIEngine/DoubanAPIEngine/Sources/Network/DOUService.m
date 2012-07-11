//
//  DOUService.m
//  DOUAPIEngine
//
//  Created by Lin GUO on 11-11-1.
//  Copyright (c) 2011年 Douban Inc. All rights reserved.
//

#import "DOUService.h"
#import "DOUHTTPRequest.h"
#import "DOUAPIConfig.h"
#import "DOUOAuthService.h"
#import "DOUOAuthStore.h"
#import "DOUQuery.h"
#import "NSString+Base64Encoding.h"

#import "ASINetworkQueue.h"


@interface DOUService ()

@property (nonatomic, retain) ASINetworkQueue   *queue;

- (void)addRequest:(DOUHttpRequest *)request;
- (void)setMaxConcurrentOperationCount:(NSUInteger)maxConcurrentOperationCount;

@end

@implementation DOUService

NSUInteger const kDefaultMaxConcurrentOperationCount = 4;

@synthesize queue = queue_;

@synthesize apiBaseUrlString = apiBaseUrlString_;
@synthesize clientId = clientId_;
@synthesize clientSecret = clientSecret_;


- (id)init {
  self = [super init];
  if (self) {
    
  }
  return self;
}


- (void)dealloc {
  [queue_ release]; queue_ = nil;
  [super dealloc];
}


#pragma mark - Singleton

static DOUService *myInstance = nil;

+ (DOUService *)sharedInstance {
  
  @synchronized(self) {
    if (myInstance == nil) {
      myInstance = [[DOUService alloc] init];
    }
    
  }
  return myInstance;
}


+ (id)allocWithZone:(NSZone *)zone {
  @synchronized(self) {
    if (myInstance == nil) {
      myInstance = [super allocWithZone:zone];
      return myInstance;  // assignment and return on first allocation
    }
  }
  return nil; 
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}


- (id)retain {
  return self;
}


- (unsigned)retainCount {
  return UINT_MAX;
}


- (oneway void)release {
  //nothing
}


- (id)autorelease {
  return self;
}



- (NSError *)executeRefreshToken {
  DOUOAuthService *service = [DOUOAuthService sharedInstance];
  service.authorizationURL = kTokenUrl;
  service.clientId = self.clientId;
  service.clientSecret = self.clientSecret;
  return [service validateRefresh];
}



- (NSDictionary *)parseQueryString:(NSString *)query {
  NSMutableDictionary *dict = [[[NSMutableDictionary alloc] initWithCapacity:6] autorelease];
  NSArray *pairs = [query componentsSeparatedByString:@"&"];
  
  for (NSString *pair in pairs) {
    NSArray *elements = [pair componentsSeparatedByString:@"="];
    NSString *key = 
    [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *val = 
    [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [dict setObject:val forKey:key];
  }
  return dict;
}


- (void)sign:(DOUHttpRequest *)request {
  DOUOAuthStore *store = [DOUOAuthStore sharedInstance];
  if (store.accessToken && ![store hasExpired]) {
    NSString *authValue = [NSString stringWithFormat:@"%@ %@", @"Bearer", store.accessToken];
    [request addRequestHeader:@"Authorization" value:authValue];      
  }
  else {
    NSString *clientId = self.clientId;
    if (!clientId) {
      return ;
    }
    
    NSURL *url = [request url];
    NSString *urlString = [url absoluteString];
    NSString *query = [url query];
    if (query) {
      NSDictionary *parameters = [self parseQueryString:query];
      
      NSArray *keys = [parameters allKeys];      
      if ([keys count]  == 0) {
        urlString = [urlString stringByAppendingFormat:@"?%@=%@", @"apikey", clientId];
      }
      else {
        urlString = [urlString stringByAppendingFormat:@"&%@=%@", @"apikey", clientId];
      }
    }
    else {
      urlString = [urlString stringByAppendingFormat:@"?%@=%@", @"apikey", clientId];  
    }
    
    NSString *afterUrl = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    request.url = [NSURL URLWithString:afterUrl];
  }
  
}


- (void)addRequest:(DOUHttpRequest *)request {
  
  if (![self queue]) {
    [self setQueue:[[[ASINetworkQueue alloc] init] autorelease]];
    self.queue.maxConcurrentOperationCount = kDefaultMaxConcurrentOperationCount;
  }
  
  DOUOAuthStore *store = [DOUOAuthStore sharedInstance];
  if (store.userId != 0 && store.refreshToken && [store shouldRefreshToken]) {
    [self executeRefreshToken];
  }
  
  [self sign:request];
  NSLog(@"request url:%@", [request.url absoluteString]);

  [[self queue] addOperation:request];
  [[self queue] go];
}


- (void)setMaxConcurrentOperationCount:(NSUInteger)maxCount {
  self.queue.maxConcurrentOperationCount = maxCount;
}


- (BOOL)isValid {
  DOUOAuthStore *store = [DOUOAuthStore sharedInstance];
  if (store.accessToken) {
    return ![store hasExpired];
  }
  return NO;
}


#if NS_BLOCKS_AVAILABLE


- (DOUHttpRequest *)get:(DOUQuery *)query callback:(DOUReqBlock)block {
  query.apiBaseUrlString = self.apiBaseUrlString;
  // __block, It tells the block not to retain the request, which is important in preventing a retain-cycle,
  // since the request will always retain the block
  __block DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query completionBlock:^{
    block(req);
  }];
  
  [req setRequestMethod:@"GET"];

  [self addRequest:req];
  return req;
}


- (DOUHttpRequest *)post:(DOUQuery *)query callback:(DOUReqBlock)block {
  query.apiBaseUrlString = self.apiBaseUrlString;
  return [self post:query object:nil callback:block];
}


- (DOUHttpRequest *)post:(DOUQuery *)query object:(GDataEntryBase *)object callback:(DOUReqBlock)block {
  query.apiBaseUrlString = self.apiBaseUrlString;

  __block DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query completionBlock:^{
    block(req);
  }];

  [req setRequestMethod:@"POST"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];
  
  if (object) {
    NSString *string = [[object XMLElement] XMLString];
    NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSString *length = [NSString stringWithFormat:@"%d", [objectData length]];
    [req appendPostData:objectData];
    [req addRequestHeader:@"CONTENT_LENGTH" value:length];    
  }
  else {
    [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];      
  }
  
  [req setResponseEncoding:NSUTF8StringEncoding];
  [self addRequest:req];
  return req;
}

- (DOUHttpRequest *)put:(DOUQuery *)query object:(GDataEntryBase *)object callback:(DOUReqBlock)block {
  query.apiBaseUrlString = self.apiBaseUrlString;

  __block DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query completionBlock:^{
    block(req);
  }];

  [req setRequestMethod:@"PUT"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];

  if (object) {
    NSString *string = [[object XMLElement] XMLString];
    NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSString *length = [NSString stringWithFormat:@"%d", [objectData length]];
    [req appendPostData:objectData];
    [req addRequestHeader:@"CONTENT_LENGTH" value:length];
  }
  else {
    [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];
  }

  [req setResponseEncoding:NSUTF8StringEncoding];
  [self addRequest:req];
  return req;
}


- (DOUHttpRequest *)post:(DOUQuery *)query 
   photoData:(NSData *)photoData
      format:(NSString *)format
 description:(NSString *)description
    callback:(DOUReqBlock)block {
  
  query.apiBaseUrlString = self.apiBaseUrlString;
  
  __block DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query completionBlock:^{
    block(req);
  }];
  
  [req setRequestMethod:@"POST"];
  [req addRequestHeader:@"Content-Type" value:@"multipart/related; boundary=\"END_OF_PART\""];
  [req addRequestHeader:@"MIME-version" value:@"1.0"];

  NSString *postContent = @"Media multipart posting\n--END_OF_PART\nContent-Type: application/atom+xml\n\n";
  
  GDataEntryBase *emptyEntry = [[GDataEntryBase alloc] init] ;
  emptyEntry.contentStringValue = description;
  NSString *descStr = [[emptyEntry XMLElement] XMLString];
  [emptyEntry release];
  postContent = [postContent stringByAppendingString:descStr];
  postContent = [postContent stringByAppendingString:@"\n--END_OF_PART"];
  postContent = [postContent stringByAppendingFormat:@"\nContent-Type: image/%@\n", format];
  
  NSString *encodingStr = [NSString base64StringFromData:photoData length:[photoData length]];
  
  postContent = [postContent stringByAppendingString:encodingStr];
  
  postContent = [postContent stringByAppendingFormat:@"--END_OF_PART--", format];
  NSData *postData = [postContent dataUsingEncoding:NSUTF8StringEncoding];
  NSInteger length = [postData length];
  [req addRequestHeader:@"Content-Length" value:[NSString stringWithFormat:@"%d", length]];
  [self addRequest:req]; 
  return req;
}


- (DOUHttpRequest *)delete:(DOUQuery *)query callback:(DOUReqBlock)block {
  
  query.apiBaseUrlString = self.apiBaseUrlString;

  __block DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query completionBlock:^{
    block(req);
  }];
  
  [req setRequestMethod:@"DELETE"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];
  [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];
  [self addRequest:req];
  return req;
}


#endif


- (DOUHttpRequest *)get:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;
  DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query target:delegate];
  [self addRequest:req];
  return req;
}


- (DOUHttpRequest *)post:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;
  return [self post:query object:nil delegate:delegate];
}

- (DOUHttpRequest *)put:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;
  return [self post:query object:nil delegate:delegate];
}


- (DOUHttpRequest *)post:(DOUQuery *)query object:(GDataEntryBase *)object delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;
  DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query target:delegate];
  
  [req setRequestMethod:@"POST"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];

  if (object) {
    NSString *string = [[object XMLElement] XMLString];
    NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSString *length = [NSString stringWithFormat:@"%d", [objectData length]];
    [req appendPostData:objectData];
    [req addRequestHeader:@"CONTENT_LENGTH" value:length];    
  }
  else {
    [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];      
  }
  
  [req setResponseEncoding:NSUTF8StringEncoding];
  [self addRequest:req];
  return req;
}

- (DOUHttpRequest *)put:(DOUQuery *)query object:(GDataEntryBase *)object delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;
  DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query target:delegate];

  [req setRequestMethod:@"POST"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];

  if (object) {
    NSString *string = [[object XMLElement] XMLString];
    NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSString *length = [NSString stringWithFormat:@"%d", [objectData length]];
    [req appendPostData:objectData];
    [req addRequestHeader:@"CONTENT_LENGTH" value:length];
  }
  else {
    [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];
  }

  [req setResponseEncoding:NSUTF8StringEncoding];
  [self addRequest:req];
  return req;
}


- (DOUHttpRequest *)delete:(DOUQuery *)query delegate:(id<DOUHttpRequestDelegate>)delegate {
  query.apiBaseUrlString = self.apiBaseUrlString;

  DOUHttpRequest * req = [DOUHttpRequest requestWithQuery:query target:delegate];
  [req setRequestMethod:@"DELETE"];
  [req addRequestHeader:@"Content-Type" value:@"application/atom+xml"];
  [req addRequestHeader:@"CONTENT_LENGTH" value:@"0"];      
  [self addRequest:req];
  return req;
}


@end
