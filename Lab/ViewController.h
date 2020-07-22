//
//  ViewController.h
//  Lab
//
//  Created by Mikko Harju on 18/07/2019.
//  Copyright © 2019 Mikko Harju. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "DataConnection.h"

@interface ViewController : NSViewController <WKUIDelegate, WKNavigationDelegate, NReplDelegate>

@property (weak) IBOutlet WKWebView *webView;
@property (strong, nonatomic) NSTask *task;
@end

