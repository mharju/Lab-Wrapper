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
#import "NRepl.h"

static const char* LISTEN_PORT = "9898";
static struct mg_serve_http_opts s_http_server_opts;

static int is_websocket(const struct mg_connection *nc) {
  return nc->flags & MG_F_IS_WEBSOCKET;
}

static void broadcast(struct mg_connection *nc, const struct mg_str msg) {
  struct mg_connection *c;
  char buf[500];
  char addr[32];
  mg_sock_addr_to_str(&nc->sa, addr, sizeof(addr),
                      MG_SOCK_STRINGIFY_IP | MG_SOCK_STRINGIFY_PORT);

  snprintf(buf, sizeof(buf), "%s %.*s", addr, (int) msg.len, msg.p);
  printf("%s\n", buf); /* Local echo. */
  for (c = mg_next(nc->mgr, NULL); c != NULL; c = mg_next(nc->mgr, c)) {
    if (c == nc) continue; /* Don't send to the sender. */
    mg_send_websocket_frame(c, WEBSOCKET_OP_TEXT, buf, strlen(buf));
  }
}

static void ev_handler(struct mg_connection *nc, int ev, void *ev_data) {
    @autoreleasepool {
    switch (ev) {
      case MG_EV_WEBSOCKET_HANDSHAKE_DONE: {
        /* New websocket connection. Tell everybody. */
        broadcast(nc, mg_mk_str("++ connected"));
        break;
      }
      case MG_EV_WEBSOCKET_FRAME: {
        struct websocket_message *wm = (struct websocket_message *) ev_data;
        /* New websocket message. Tell everybody. */
        struct mg_str d = {(char *) wm->data, wm->size};
        broadcast(nc, d);
        break;
      }
      case MG_EV_HTTP_REQUEST: {
        mg_serve_http(nc, (struct http_message *) ev_data, s_http_server_opts);
        break;
      }
      case MG_EV_CLOSE: {
        /* Disconnect. Tell everybody. */
        if (is_websocket(nc)) {
          broadcast(nc, mg_mk_str("-- left"));
        }
        break;
      }
    }
    }
}

static void *start_server() {
    struct mg_mgr mgr;
    struct mg_connection *nc;

    mg_mgr_init(&mgr, NULL);
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
    NRepl *nrepl;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    pthread_create(&http_server, NULL, start_server, NULL);

    nrepl = [[NRepl alloc] init];
    [nrepl start];
    
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
@end
