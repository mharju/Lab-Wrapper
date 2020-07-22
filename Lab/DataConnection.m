//
//  DataConnection.m
//  Lab
//
//  Created by Mikko Harju on 07/06/2020.
//  Copyright © 2020 Mikko Harju. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <ifaddrs.h>
#include <arpa/inet.h>

#import "DataConnection.h"

static const uint16 TCP_LISTEN_PORT = 9889;

@interface DataConnection () {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
}
@property (strong, nonatomic) id<DataConnectionDelegate> delegate;
- (void) pairStreams:(CFSocketNativeHandle)handle;
@end

static void handleConnect(CFSocketRef s,
                          CFSocketCallBackType callbackType,
                          CFDataRef address,
                          const void *data,
                          void *info) {
    DataConnection* delegate = (__bridge DataConnection*)info;
    if(callbackType == kCFSocketAcceptCallBack) {
        NSLog(@"Pair streams.");
        [delegate pairStreams:(CFSocketNativeHandle)*(const int*)data];
    }
}

@implementation DataConnection
- (instancetype) initWithDelegate:(id<DataConnectionDelegate>)delegate {
    if (self = [super init]) {
        self.delegate = delegate;
    }
    return self;
}
- (void) start {
    CFSocketContext context;
      memset(&context, 0, sizeof(context));
      context.info = (__bridge void *)(self);
      
      // Setup network
      CFSocketRef myipv4cfsock = CFSocketCreate(kCFAllocatorDefault,
                                                PF_INET,
                                                SOCK_STREAM,
                                                IPPROTO_TCP,
                                                kCFSocketAcceptCallBack, handleConnect, &context);
      
      struct sockaddr_in sin;
      
      memset(&sin, 0, sizeof(sin));
      sin.sin_len = sizeof(sin);
      sin.sin_family = AF_INET; /* Address family */
      sin.sin_port = htons(TCP_LISTEN_PORT); /* Or a specific port */
      sin.sin_addr.s_addr = INADDR_ANY;
      
      CFDataRef sincfd = CFDataCreate(
                                      kCFAllocatorDefault,
                                      (const UInt8*)&sin,
                                      sizeof(sin));
      
      CFSocketSetAddress(myipv4cfsock, sincfd);
      
      CFRunLoopSourceRef socketsource = CFSocketCreateRunLoopSource(
                                                                    kCFAllocatorDefault,
                                                                    myipv4cfsock,
                                                                    0);
      
      CFRunLoopAddSource(
                         CFRunLoopGetCurrent(),
                         socketsource,
                         kCFRunLoopDefaultMode);
          
       NSLog(@"Started data service at tcp://localhost:%u\n", TCP_LISTEN_PORT);
}

- (void) pairStreams:(CFSocketNativeHandle)handle
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, handle, &readStream, &writeStream);

    inputStream = (__bridge_transfer NSInputStream *)readStream;
    outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [inputStream setProperty:(id)kCFBooleanTrue forKey:(NSString*)kCFStreamPropertyShouldCloseNativeSocket];
    [outputStream setProperty:(id)kCFBooleanTrue forKey:(NSString*)kCFStreamPropertyShouldCloseNativeSocket];
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream open];
    [outputStream open];
}

- (void) closeConnection
{
    NSLog(@"Close connection..");
    [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream close];
    [inputStream close];
    outputStream.delegate = nil;
    inputStream.delegate = nil;
    outputStream = nil;
    inputStream = nil;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"Client connected.");
            break;
        case NSStreamEventHasBytesAvailable: {
            char buf[1024] = {0};
            NSInteger len = 0;
            if((len = [inputStream read:(uint8_t*)&buf[0] maxLength:1024]) > 0) {
                buf[len] = '\0';
                NSLog(@"Data received. Broadcasting.");
                [[self delegate] sendBroadcast:self forData:&buf[0]];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            break;
        }
        case NSStreamEventEndEncountered:
        case NSStreamEventErrorOccurred:
            NSLog(@"Client disconnected.");
            inputStream.delegate = nil;
            outputStream.delegate = nil;
            inputStream = nil;
            outputStream = nil;
            break;
            
        default:
            NSLog(@"Unknown %ld", eventCode);
    }
}

- (void) sendResponseForData:(const char *)result length:(size_t)length {
    [outputStream write:(uint8_t*)result maxLength:length];
}
@end
