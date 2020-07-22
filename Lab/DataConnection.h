//
//  DataConnection.h
//  Lab
//
//  Created by Mikko Harju on 07/06/2020.
//  Copyright © 2020 Mikko Harju. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataConnection;

NS_ASSUME_NONNULL_BEGIN

@protocol DataConnectionDelegate <NSObject>
@optional
- (void) sendBroadcast:(DataConnection*)repl forData:(const char*)data;
@end

@interface DataConnection : NSObject <NSStreamDelegate>
- (instancetype) initWithDelegate:(id<DataConnectionDelegate>)delegate;
- (void) start;
- (void) sendResponseForData:(const char*)result length:(size_t)length;
@end

NS_ASSUME_NONNULL_END
