/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import <AppKit/AppKit.h>

@class AppMenuWidget;

/**
 * ActionSearchResult - Represents a searchable menu item
 */
@interface ActionSearchResult : NSObject

@property (nonatomic, strong) NSString *title;           // Menu item title
@property (nonatomic, strong) NSString *path;            // Full path like "File ▸ Open"
@property (nonatomic, strong) NSString *keyEquivalent;   // Keyboard shortcut string
@property (nonatomic, assign) NSUInteger modifierMask;   // Modifier keys
@property (nonatomic, strong) NSMenuItem *menuItem;      // Reference to actual menu item
@property (nonatomic, assign) BOOL enabled;              // Whether item is enabled in original menu

- (id)initWithMenuItem:(NSMenuItem *)item path:(NSString *)path;

@end


/**
 * ActionSearchSubmenu - Presents a Spotlight-like search panel that is anchored to the
 *                       Search menu item but implemented as its own NSPanel. The menu
 *                       system stays untouched – no method swizzling or view overlays.
 */
@interface ActionSearchSubmenu : NSObject <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong, readonly) NSTextField *searchField;
@property (nonatomic, strong, readonly) NSPanel *searchPanel;
@property (nonatomic, weak) AppMenuWidget *appMenuWidget;

+ (instancetype)sharedSubmenu;

/** Create the trailing “Search” menu item. Target/action can be reassigned by caller. */
- (NSMenuItem *)createSearchMenuItem;

/** Configure the widget we collect items from. */
- (void)setAppMenuWidget:(AppMenuWidget *)widget;

/** Collect all actionable menu items from the current application menu. */
- (void)collectMenuItems;

/** Execute the selected menu item. */
- (void)executeActionForResult:(ActionSearchResult *)result;

/** Toggle/show the panel anchored to the given screen rect (usually the Search item). */
- (void)toggleSearchAnchoredToRect:(NSRect)anchorRect;
- (void)showSearchAnchoredToRect:(NSRect)anchorRect;

/** Hide the search UI. */
- (void)hideSearch;

/** True while the panel is visible. */
- (BOOL)isVisible;

/** Update results after text changes. */
- (void)updateSearchResults:(NSString *)searchText;

@end


/**
 * ActionSearchController - Legacy support wrapper around ActionSearchSubmenu
 */
@interface ActionSearchController : NSObject <NSTextFieldDelegate>

@property (nonatomic, strong) NSMutableArray *allMenuItems;
@property (nonatomic, strong) NSMutableArray *filteredResults;
@property (nonatomic, weak) AppMenuWidget *appMenuWidget;

+ (instancetype)sharedController;

- (void)setAppMenuWidget:(AppMenuWidget *)widget;
- (void)hideSearchPopup;
- (void)toggleSearchPopupAtPoint:(NSPoint)point;
- (void)collectMenuItems;
- (void)executeActionForResult:(ActionSearchResult *)result;
- (void)searchMenuItemClicked:(id)sender;
- (void)searchMenuItemClicked:(id)sender atPoint:(NSPoint)point;
- (void)checkIfClickIsOutside:(NSEvent *)event;

@end

