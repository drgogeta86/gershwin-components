/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import "MenuBarView.h"

@implementation MenuBarView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
         // Use the theme's menubar background color instead of hardcoded values
        self.backgroundColor = [[GSTheme theme] menuItemBackgroundColor];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSLog(@"MenuBarView: drawRect called with rect: %.0f,%.0f %.0fx%.0f, bounds: %.0f,%.0f %.0fx%.0f", 
          dirtyRect.origin.x, dirtyRect.origin.y, dirtyRect.size.width, dirtyRect.size.height,
          self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    
    // Fill with theme background color - this provides the base for the entire menu bar
    if (self.backgroundColor) {
        [self.backgroundColor set];
        NSRectFill([self bounds]);
        
        // Log the color details
        CGFloat r,g,b,a;
        [[self.backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
        NSLog(@"MenuBarView: Drew theme background color: rgba=%.3f %.3f %.3f %.3f", r,g,b,a);
    } else {
        // Fallback to light gray if theme color is unavailable
        [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] set];
        NSRectFill([self bounds]);
        NSLog(@"MenuBarView: Warning - used fallback background color");
    }
}

- (BOOL)isOpaque
{
    return YES;
}

@end
