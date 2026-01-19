/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "StatusItemsView.h"

/**
 * Custom NSMenuView subclass for status items.
 * Renders transparently over MenuBarView background.
 */
@interface TransparentMenuView : NSMenuView
@end

@implementation TransparentMenuView

- (void)drawRect:(NSRect)dirtyRect
{
    // Clear background only on full redraws for transparency
    if (NSEqualRects(dirtyRect, [self bounds])) {
        [[NSColor clearColor] set];
        NSRectFill(dirtyRect);
    }
    [super drawRect:dirtyRect];
}

- (BOOL)isOpaque
{
    return NO;
}

@end

@implementation StatusItemsView

- (instancetype)initWithFrame:(NSRect)frame statusMenu:(NSMenu *)menu
{
    self = [super initWithFrame:frame];
    if (self) {
        self.statusMenu = menu;
        
        // Create menu view filling the entire frame
        self.menuView = [[TransparentMenuView alloc] initWithFrame:[self bounds]];
        [self.menuView setMenu:menu];
        [self.menuView setHorizontal:YES];
        [self.menuView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self addSubview:self.menuView];
        
        [self setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
    }
    return self;
}

- (BOOL)isOpaque
{
    return NO;
}

@end
