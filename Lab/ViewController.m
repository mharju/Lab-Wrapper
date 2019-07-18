//
//  ViewController.m
//  Lab
//
//  Created by Mikko Harju on 18/07/2019.
//  Copyright © 2019 Mikko Harju. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString: @"http://localhost:9500"]];
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
