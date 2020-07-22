//
//  NRepl.h
//  Lab
//
//  Created by Mikko Harju on 07/06/2020.
//  Copyright © 2020 Mikko Harju. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataConnection;

NS_ASSUME_NONNULL_BEGIN

@protocol NReplDelegate <NSObject>
@optional
- (void) sendBroadcast:(DataConnection*)repl forEvaluation:(const uint8_t*)data;
@end

@interface DataConnection : NSObject <NSStreamDelegate>
- (instancetype) initWithDelegate:(id<NReplDelegate>)delegate;
- (void) start;
- (void) setResponseForEvaluation:(const uint8_t*)result length:(int)length;
@end

NS_ASSUME_NONNULL_END
