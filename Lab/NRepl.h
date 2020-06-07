//
//  NRepl.h
//  Lab
//
//  Created by Mikko Harju on 07/06/2020.
//  Copyright © 2020 Mikko Harju. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRepl;

NS_ASSUME_NONNULL_BEGIN

@protocol NReplDelegate <NSObject>
@optional
- sendBroadcast:(NRepl*)repl forEvaluation:(NSString*)data;
@end

@interface NRepl : NSObject <NSStreamDelegate>
- (instancetype) initWithDelegate:(id<NReplDelegate>)delegate;
- (void) start;
- setResponseForEvaluation:(NSString*)result;
@end

NS_ASSUME_NONNULL_END
