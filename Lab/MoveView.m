//
//  MoveView.m
//  Lab
//
//  Created by Mikko Harju on 18/07/2019.
//  Copyright © 2019 Mikko Harju. All rights reserved.
//

#import "MoveView.h"

@implementation MoveView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)mouseDown:(NSEvent *)event
{
    [self.window performWindowDragWithEvent:event];
}
@end
