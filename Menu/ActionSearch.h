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
 * ActionSearchSubmenu - Shows a search field when Search menu is clicked
 * 
 * When "Search" in the menu bar is clicked:
 * 1. A small window appears below containing just a search field (sized like a menu item)
 * 2. As user types, matching results appear in a regular NSMenu positioned below the search field
 * 3. This makes the search field + results look like one continuous dropdown menu
 */
@interface ActionSearchSubmenu : NSObject <NSTextFieldDelegate>

@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSPanel *searchFieldPanel;      // Small panel for search field
@property (nonatomic, strong) NSMenu *resultsMenu;            // Regular menu for results
@property (nonatomic, strong) NSMutableArray *allMenuItems;
@property (nonatomic, strong) NSMutableArray *filteredResults;
@property (nonatomic, weak) AppMenuWidget *appMenuWidget;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) CGFloat searchItemX;  // X coordinate of Search menu item

+ (instancetype)sharedSubmenu;

/**
 * Create a "Search" menu item (no submenu - clicking opens search panel)
 */
- (NSMenuItem *)createSearchMenuItem;

/**
 * Set the app menu widget reference to access current menus
 */
- (void)setAppMenuWidget:(AppMenuWidget *)widget;

/**
 * Set the X coordinate of the Search menu item for positioning
 */
- (void)setSearchItemX:(CGFloat)xCoord;

/**
 * Collect all menu items from the current application menu
 */
- (void)collectMenuItems;

/**
 * Execute the selected action
 */
- (void)executeActionForResult:(ActionSearchResult *)result;

/**
 * Show the search panel below the Search menu item
 */
- (void)showSearchPanel;

/**
 * Show the search panel at specified X coordinate
 */
- (void)showSearchPanelAtX:(NSNumber *)xCoord;

/**
 * Hide search and cleanup
 */
- (void)hideSearch;

/**
 * Update results based on current search text
 */
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

