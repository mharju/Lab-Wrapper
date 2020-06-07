//
//  NRepl.m
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
#include "bencode.h"

#import "NRepl.h"

static const uint16 NREPL_LISTEN_PORT = 9897;

@interface NRepl () {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
}
@property (strong, nonatomic) id<NReplDelegate> delegate;
- (void) pairStreams:(CFSocketNativeHandle)handle;
@end

static void handleConnect(CFSocketRef s,
                          CFSocketCallBackType callbackType,
                          CFDataRef address,
                          const void *data,
                          void *info) {
    NRepl* delegate = (__bridge NRepl*)info;
    if(callbackType == kCFSocketAcceptCallBack) {
        NSLog(@"Pair streams.");
        [delegate pairStreams:(CFSocketNativeHandle)*(const int*)data];
    }
}

@implementation NRepl
- (instancetype) initWithDelegate:(id<NReplDelegate>)delegate {
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
      sin.sin_port = htons(NREPL_LISTEN_PORT); /* Or a specific port */
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
          
       NSLog(@"Started NREPL server at nrepl://localhost:%d\n", NREPL_LISTEN_PORT);
}

- (void) pairStreams:(CFSocketNativeHandle)handle
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, handle, &readStream, &writeStream);

    inputStream = (__bridge_transfer NSInputStream *)readStream;
    outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [inputStream setProperty:(id)kCFBooleanTrue forKey:kCFStreamPropertyShouldCloseNativeSocket];
    [outputStream setProperty:(id)kCFBooleanTrue forKey:kCFStreamPropertyShouldCloseNativeSocket];
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
            uint8_t buf[1024] = {0};
            NSInteger len = 0;
            if((len = [inputStream read:&buf[0] maxLength:1024]) > 0) {
                buf[len] = '\0';
                
                struct bencode bc = {0};
                bencode_init(&bc, buf, len);
                int token = -1;
                do {
                    token = bencode_next(&bc);
                    switch(token) {
                        case BENCODE_STRING: {
                            char b[1024] = {0};
                            strncpy(b, bc.tok, bc.toklen);
                            NSLog(@"String. %s", b);
                            break;
                        }
                        case BENCODE_INTEGER:
                            NSLog(@"Integer. %d", (int)bc.tok);
                            break;
                        case BENCODE_DICT_BEGIN:
                            NSLog(@"Dict begin");
                            break;
                        case BENCODE_DICT_END:
                            NSLog(@"Dict end");
                            break;
                    }
                } while(token != BENCODE_DONE);
                NSLog(@"Parsing done.");
                // Example: d3:cow3:moo4:spam4:eggse represents the dictionary { "cow" => "moo", "spam" => "eggs" }
                //
                // l5:close9:classpath8:describe4:evale
                const uint8_t response[] = "d3:opsl5:close9:classpath8:describe4:evalee\n";
                [outputStream write:&response[0] maxLength:44];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            NSLog(@"Has space available.");
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
@end
