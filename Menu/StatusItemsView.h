/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/**
 * Container view for status items displayed at the right edge of the menu bar.
 * Uses NSMenuView for rendering status items as proper menu items with consistent styling.
 * Status items are ordered by displayPriority (higher priority = rightmost position).
 */
@interface StatusItemsView : NSView

@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) NSMenuView *menuView;

/**
 * Initialize with frame and menu containing status items.
 * @param frame The frame for the container view
 * @param menu The NSMenu containing status item menu items
 */
- (instancetype)initWithFrame:(NSRect)frame statusMenu:(NSMenu *)menu;

@end
