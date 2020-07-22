//
//  ViewController.m
//  Lab
//
//  Created by Mikko Harju on 18/07/2019.
//  Copyright © 2019 Mikko Harju. All rights reserved.
//

#import "ViewController.h"
#include <pthread.h>
#include "mongoose.h"

static const char* LISTEN_PORT = "9898";
static struct mg_serve_http_opts s_http_server_opts;
static struct mg_connection *ws_connection = NULL;

static int is_websocket(const struct mg_connection *nc) {
  return nc->flags & MG_F_IS_WEBSOCKET;
}

static void broadcast(struct mg_connection *nc, const struct mg_str msg) {
  struct mg_connection *c;
    
  for (c = mg_next(nc->mgr, NULL); c != NULL; c = mg_next(nc->mgr, c)) {
      if (c != NULL) {
          mg_send_websocket_frame(c, WEBSOCKET_OP_TEXT, msg.p, msg.len);
      }
  }
}

static void ev_handler(struct mg_connection *nc, int ev, void *ev_data) {
    @autoreleasepool {
    switch (ev) {
      case MG_EV_WEBSOCKET_HANDSHAKE_DONE: {
        ws_connection = nc;
        break;
      }
      case MG_EV_WEBSOCKET_FRAME: {
        struct websocket_message *wm = (struct websocket_message *) ev_data;
        struct mg_str d = {(char *) wm->data, wm->size};
        [(__bridge DataConnection*)nc->mgr->user_data setResponseForEvaluation:d.p length:d.len];
        break;
      }
      case MG_EV_HTTP_REQUEST: {
        mg_serve_http(nc, (struct http_message *) ev_data, s_http_server_opts);
        break;
      }
      case MG_EV_CLOSE: {
        if (is_websocket(nc)) {
          ws_connection = NULL;
        }
        break;
      }
    }
    }
}

static void *start_server(void *nrepl) {
    struct mg_mgr mgr;
    struct mg_connection *nc;

    mg_mgr_init(&mgr, nrepl);
    NSLog(@"Starting web server on port %s\n", LISTEN_PORT);
    nc = mg_bind(&mgr, LISTEN_PORT, ev_handler);
    
    // Set up HTTP server parameters
    mg_set_protocol_http_websocket(nc);
    s_http_server_opts.document_root = [[NSString stringWithFormat:@"%@/public",
                                          [[NSBundle mainBundle] resourcePath]] cStringUsingEncoding:NSUTF8StringEncoding];
    s_http_server_opts.enable_directory_listing = "yes";

    for (;;) {
      mg_mgr_poll(&mgr, 1000);
    }
}

@interface ViewController () {
    pthread_t http_server;
    DataConnection *nrepl;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    nrepl = [[DataConnection alloc] initWithDelegate:self];
    [nrepl start];

    pthread_create(&http_server, NULL, start_server, (__bridge void*)nrepl);

    NSURLRequest *req = [NSURLRequest requestWithURL:
                         [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://localhost:%s", LISTEN_PORT]]];
    [self.webView loadRequest:req];
}

- (void)viewDidDisappear
{
    if(self.task != nil) {
        [self.task terminate];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"Content loaded");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"Could not load content :(");
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    NSLog(@"%@", message);
    completionHandler();
}

- (void) sendBroadcast:(DataConnection *)repl forEvaluation:(const uint8_t *)data {
    NSLog(@"Broadcast %s", data);
    broadcast(ws_connection, mg_mk_str(data));
}
@end
