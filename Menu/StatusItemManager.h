/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "StatusItemProvider.h"

/**
 * Manages all status items displayed in the menu bar.
 * Responsible for loading bundles, managing the status menu, and coordinating updates.
 */
@interface StatusItemManager : NSObject

/**
 * Array of loaded status item providers.
 */
@property (nonatomic, strong) NSMutableArray<id<StatusItemProvider>> *statusItems;

/**
 * Dictionary mapping update intervals to timers.
 * Key: NSNumber with updateInterval, Value: NSTimer
 */
@property (nonatomic, strong) NSMutableDictionary *updateTimers;

/**
 * Dictionary mapping status item identifiers to their NSMenuItems.
 * Key: identifier string, Value: NSMenuItem
 */
@property (nonatomic, strong) NSMutableDictionary *menuItems;

/**
 * The menu containing status item menu items.
 */
@property (nonatomic, strong) NSMenu *statusMenu;

/**
 * Current cached widths for providers.
 * Key: identifier string -> NSNumber width
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *currentWidths;

/**
 * The parent view that contains status items display.
 */
@property (nonatomic, weak) NSView *containerView;

/**
 * Total width of screen available.
 */
@property (nonatomic, assign) CGFloat screenWidth;

/**
 * Height of the menu bar.
 */
@property (nonatomic, assign) CGFloat menuBarHeight;

/**
 * Initialize with the container view and dimensions.
 *
 * @param container The view that will contain status items
 * @param width Screen width
 * @param height Menu bar height
 */
- (instancetype)initWithContainerView:(NSView *)container
                          screenWidth:(CGFloat)width
                        menuBarHeight:(CGFloat)height;

/**
 * Load all status item bundles from standard locations.
 * Searches in:
 * - /System/Library/Menu/StatusItems/
 * - ~/Library/Menu/StatusItems/
 * - Menu.app/Contents/Resources/StatusItems/
 */
- (void)loadStatusItems;

/**
 * Load a specific status item bundle.
 *
 * @param bundle The NSBundle to load
 * @param loadedIdentifiers Set of already loaded identifiers to prevent duplicates
 * @return YES if loaded successfully, NO otherwise
 */
- (BOOL)loadStatusItemFromBundle:(NSBundle *)bundle loadedIdentifiers:(NSMutableSet *)loadedIdentifiers;

/**
 * Populate the status menu with menu items from loaded providers.
 * Items are added based on their display priority.
 */
- (void)layoutStatusItems;

/**
 * Start update timers for all status items.
 * Coalesces items with the same update interval to use one timer.
 */
- (void)startUpdateTimers;

/**
 * Stop all update timers.
 */
- (void)stopUpdateTimers;

/**
 * Unload all status items and clean up resources.
 */
- (void)unloadAllStatusItems;

/**
 * Handle click on a status item menu item.
 * Called when a menu item in the status menu is clicked.
 *
 * @param sender The NSMenuItem that was clicked (has representedObject with identifier)
 */
- (void)statusItemClicked:(id)sender;

/**
 * Request a relayout when a provider's width changes.
 *
 * @param provider The status item provider requesting relayout
 */
- (void)requestRelayoutForProvider:(id<StatusItemProvider>)provider;

@end
