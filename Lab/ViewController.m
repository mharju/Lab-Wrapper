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
#include "bencode.h"
#include "postgres.h"

static const char* LISTEN_PORT = "9898";
static struct mg_serve_http_opts s_http_server_opts;
static struct mg_connection *ws_connection = NULL;
static connection_t *pg_connection = NULL;

static const struct bencode *COMMAND = NULL;
static const struct bencode *PARAMS = NULL;
static const struct bencode *CONNECT = NULL;
static const struct bencode *QUERY = NULL;
static const struct bencode *ID = NULL;

static int is_websocket(const struct mg_connection *nc) {
  return nc->flags & MG_F_IS_WEBSOCKET;
}

static void send_to_primary(struct mg_connection *nc, const struct mg_str msg) {
    mg_send_websocket_frame(ws_connection, WEBSOCKET_OP_TEXT, msg.p, msg.len);
}

static void handle_websocket_message(struct mg_connection* nc, struct websocket_message *wm) {
    NSLog(@"Received %s", wm->data);
    struct bencode *b = ben_decode(wm->data, wm->size);
    struct bencode *params = ben_dict_get(b, PARAMS);
    if (ben_cmp(CONNECT, ben_dict_get(b, COMMAND)) == 0) {
        NSLog(@"Connect to %s", ben_str_val(params));
        if (pg_connection != NULL) {
            PQfinish(pg_connection->conn);
            free(pg_connection);
            pg_connection = NULL;
        }
        const char* conninfo = ben_str_val(params);
        pg_connection = pg_connect(conninfo, strlen(conninfo));
    } else if(ben_cmp(QUERY, ben_dict_get(b, COMMAND)) == 0) {
        NSLog(@"Query %s", ben_str_val(ben_dict_get(params, QUERY)));
        long long query_id = ben_int_val(ben_dict_get(params, ID));
        struct bencode *result = pg_query(pg_connection, ben_str_val(ben_dict_get(params, QUERY)));
        ben_dict_set(result, ben_str("id"), ben_int(query_id));
        ben_dict_set(result, ben_str("command"), ben_str("query"));
        size_t len = 0;
        const char* encoded = ben_encode(&len, result);
        NSLog(@"Send %s", encoded);
        ben_free(result);
        struct mg_str d = {(char *) encoded, len};
        send_to_primary(nc, d);
        free((void*)encoded);
    }
    ben_free(b);
}

static void ev_handler(struct mg_connection *nc, int ev, void *ev_data) {
    @autoreleasepool {
    switch (ev) {
      case MG_EV_WEBSOCKET_HANDSHAKE_DONE: {
        if(ws_connection == NULL) {
          NSLog(@"Primary connect");
          ws_connection = nc;
        }
        break;
      }
      case MG_EV_WEBSOCKET_FRAME: {
        handle_websocket_message(nc, (struct websocket_message *) ev_data);
        break;
      }
      case MG_EV_HTTP_REQUEST: {
        mg_serve_http(nc, (struct http_message *) ev_data, s_http_server_opts);
        break;
      }
      case MG_EV_CLOSE: {
        if (is_websocket(nc) && nc == ws_connection) {
          NSLog(@"Primary disconnect");
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

    // alloc bencode constants
    COMMAND = ben_str("command");
    PARAMS = ben_str("params");
    CONNECT = ben_str("connect");
    QUERY = ben_str("query");
    ID = ben_str("id");

    mg_mgr_init(&mgr, nrepl);
    NSLog(@"Starting web server on port %s\n", LISTEN_PORT);
    nc = mg_bind(&mgr, LISTEN_PORT, ev_handler);
    
    // Set up HTTP server parameters
    mg_set_protocol_http_websocket(nc);
/*    s_http_server_opts.document_root = [[NSString stringWithFormat:@"%@/public",
                                          [[NSBundle mainBundle] resourcePath]] cStringUsingEncoding:NSUTF8StringEncoding];*/
    s_http_server_opts.document_root = "/Users/maharj/Development/clojure/lab/resources/public";

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

- (void) sendBroadcast:(DataConnection *)repl forData:(const char *)data {
    struct mg_str d = mg_mk_str(data);
    mg_send_websocket_frame(ws_connection, WEBSOCKET_OP_TEXT, d.p, d.len);
}
@end
