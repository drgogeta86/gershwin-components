/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import "ActionSearch.h"
#import "AppMenuWidget.h"
#import "X11ShortcutManager.h"
#import <GNUstepGUI/GSTheme.h>
#import <pthread.h>

// Singleton instances
static ActionSearchSubmenu *_sharedSubmenu = nil;
static ActionSearchController *_sharedController = nil;
static pthread_mutex_t _singletonMutex = PTHREAD_MUTEX_INITIALIZER;

static const CGFloat kSearchFieldWidth = 200;
static const CGFloat kSearchFieldHeight = 22;
static const CGFloat kMaxResultsShown = 15;


#pragma mark - ActionSearchPanel (custom panel that accepts keyboard)

@interface ActionSearchPanel : NSPanel
@end

@implementation ActionSearchPanel

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end


#pragma mark - ActionSearchResult

@implementation ActionSearchResult

- (id)initWithMenuItem:(NSMenuItem *)item path:(NSString *)path
{
    self = [super init];
    if (self) {
        self.menuItem = item;
        self.title = [item title];
        self.path = path;
        self.keyEquivalent = [item keyEquivalent] ?: @"";
        self.modifierMask = [item keyEquivalentModifierMask];
        self.enabled = [item isEnabled];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"ActionSearchResult: %@ (%@)", self.title, self.path];
}

@end


#pragma mark - ActionSearchSubmenu

@implementation ActionSearchSubmenu

+ (instancetype)sharedSubmenu
{
    pthread_mutex_lock(&_singletonMutex);
    if (_sharedSubmenu == nil) {
        _sharedSubmenu = [[ActionSearchSubmenu alloc] init];
    }
    pthread_mutex_unlock(&_singletonMutex);
    return _sharedSubmenu;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.allMenuItems = [NSMutableArray array];
        self.filteredResults = [NSMutableArray array];
        self.isSearching = NO;
        
        [self createSearchFieldPanel];
        [self createResultsMenu];
        
        // Listen for app deactivation to close search
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidResignActive:)
                                                     name:NSApplicationDidResignActiveNotification
                                                   object:[NSApplication sharedApplication]];
                                                   
        NSLog(@"ActionSearchSubmenu: Initialized");
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)createSearchFieldPanel
{
    // Create a small panel just for the search field
    // Use borderless style - keyboard routing is handled in MenuApplication.sendEvent:
    NSRect panelRect = NSMakeRect(0, 0, kSearchFieldWidth + 16, kSearchFieldHeight + 12);
    
    self.searchFieldPanel = [[ActionSearchPanel alloc] initWithContentRect:panelRect
                                                                 styleMask:NSBorderlessWindowMask
                                                                   backing:NSBackingStoreBuffered
                                                                     defer:NO];
    [self.searchFieldPanel setLevel:NSPopUpMenuWindowLevel];
    [self.searchFieldPanel setHasShadow:YES];
    [self.searchFieldPanel setOpaque:YES];
    [self.searchFieldPanel setBackgroundColor:[[GSTheme theme] menuBackgroundColor]];
    [self.searchFieldPanel setBecomesKeyOnlyIfNeeded:NO];
    [self.searchFieldPanel setReleasedWhenClosed:NO];
    
    // Hide from taskbar and window list to prevent menu bar changes when shown
    // Set window type hints to skip taskbar and pager
    [self.searchFieldPanel setExcludedFromWindowsMenu:YES];
    
    // Create search field (use NSTextField which works better with borderless windows)
    self.searchField = (NSSearchField *)[[NSTextField alloc] initWithFrame:
        NSMakeRect(8, 6, kSearchFieldWidth, kSearchFieldHeight)];
    [self.searchField setDelegate:self];
    [self.searchField setBordered:YES];
    [self.searchField setBezeled:YES];
    [self.searchField setBezelStyle:NSTextFieldRoundedBezel];
    [self.searchField setEditable:YES];
    [self.searchField setSelectable:YES];
    [self.searchField setEnabled:YES];
    [self.searchField setFont:[NSFont systemFontOfSize:12]];
    
    // Placeholder
    NSAttributedString *placeholder = [[NSAttributedString alloc] 
        initWithString:@"Search menus..."
        attributes:@{
            NSForegroundColorAttributeName: [NSColor grayColor],
            NSFontAttributeName: [NSFont systemFontOfSize:12]
        }];
    [[self.searchField cell] setPlaceholderAttributedString:placeholder];
    
    [[self.searchFieldPanel contentView] addSubview:self.searchField];
    
    NSLog(@"ActionSearchSubmenu: Created search field panel");
}

- (void)createResultsMenu
{
    self.resultsMenu = [[NSMenu alloc] initWithTitle:@"Search Results"];
    [self.resultsMenu setAutoenablesItems:NO];
    
    NSLog(@"ActionSearchSubmenu: Created results menu");
}

- (void)setAppMenuWidget:(AppMenuWidget *)widget
{
    _appMenuWidget = widget;
}

- (void)setSearchItemX:(CGFloat)xCoord
{
    // Use direct ivar assignment to avoid infinite recursion with the property
    _searchItemX = xCoord;
}

- (NSMenuItem *)createSearchMenuItem
{
    // Create a simple "Search" menu item - no submenu
    NSMenuItem *searchItem = [[NSMenuItem alloc] initWithTitle:@"Search" 
                                                        action:@selector(showSearchPanel) 
                                                 keyEquivalent:@""];
    [searchItem setTarget:self];
    [searchItem setTag:1001];
    
    NSLog(@"ActionSearchSubmenu: Created Search menu item");
    return searchItem;
}

#pragma mark - Panel Display

- (void)showSearchPanelAtX:(NSNumber *)xCoord
{
    // Store the X coordinate for use by results menu
    self.searchItemX = [xCoord floatValue];
    NSLog(@"ActionSearchSubmenu: showSearchPanelAtX called with X=%.0f", self.searchItemX);
    [self showSearchPanel];
}

- (void)showSearchPanel
{
    NSLog(@"ActionSearchSubmenu: showSearchPanel called");
    
    // If already showing, toggle off
    if (self.isSearching) {
        [self hideSearch];
        return;
    }
    
    // Collect menu items
    [self collectMenuItems];
    
    // Suspend key grabs for typing
    [[X11ShortcutManager sharedManager] suspendKeyGrabs];
    
    // Reset state
    [(NSTextField *)self.searchField setStringValue:@""];
    [self.filteredResults removeAllObjects];
    
    // Highlight the Search menu item
    [self highlightSearchMenuItem];
    
    // Position the search panel below the Search menu item
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    CGFloat menuBarHeight = 28;
    
    // Use stored X coordinate if available, otherwise compute it
    CGFloat searchX = self.searchItemX;
    if (searchX <= 0 && self.appMenuWidget) {
        NSMenu *menu = [self.appMenuWidget currentMenu];
        if (menu) {
            NSMenuView *menuView = [menu menuRepresentation];
            if (menuView) {
                NSInteger searchIndex = [menu indexOfItemWithTitle:@"Search"];
                if (searchIndex >= 0) {
                    NSRect itemRect = [menuView rectOfItemAtIndex:searchIndex];
                    NSView *superview = [self.appMenuWidget superview];
                    if (superview) {
                        NSWindow *menuWindow = [superview window];
                        if (menuWindow) {
                            NSPoint itemOriginInWindow = [menuView convertPoint:itemRect.origin toView:nil];
                            NSRect windowFrame = [menuWindow frame];
                            searchX = windowFrame.origin.x + itemOriginInWindow.x;
                            self.searchItemX = searchX;
                        }
                    }
                }
            }
        }
    }
    
    // Default fallback
    if (searchX <= 0) {
        searchX = 50;
        self.searchItemX = searchX;
    }
    
    // Position panel below the menu bar
    NSRect panelFrame = [self.searchFieldPanel frame];
    panelFrame.origin.x = searchX;
    panelFrame.origin.y = screenFrame.size.height - menuBarHeight - panelFrame.size.height;
    
    // Keep on screen
    if (NSMaxX(panelFrame) > NSMaxX(screenFrame)) {
        panelFrame.origin.x = NSMaxX(screenFrame) - panelFrame.size.width - 10;
    }
    if (panelFrame.origin.x < screenFrame.origin.x) {
        panelFrame.origin.x = screenFrame.origin.x + 10;
    }
    
    [self.searchFieldPanel setFrame:panelFrame display:YES];
    
    // Bring the panel to front but don't make it the key window
    // This keeps the menu bar showing the original application menus
    [self.searchFieldPanel orderFront:nil];
    
    // Focus the search field for keyboard input
    [self.searchFieldPanel makeFirstResponder:self.searchField];
    
    self.isSearching = YES;
    
    NSLog(@"ActionSearchSubmenu: Search panel shown at %.0f, %.0f", panelFrame.origin.x, panelFrame.origin.y);
}

- (void)showSearchSubmenuForMenuItem:(NSMenuItem *)menuItem
{
    (void)menuItem;
    [self showSearchPanel];
}

- (void)hideSearch
{
    self.isSearching = NO;
    [self.searchFieldPanel orderOut:nil];
    
    // Hide the results menu popup without removing items (so they persist for next time)
    NSWindow *menuWindow = [self.resultsMenu window];
    if (menuWindow) {
        [menuWindow orderOut:nil];
    }
    
    // Un-highlight the Search menu item
    [self unhighlightSearchMenuItem];
    
    [[X11ShortcutManager sharedManager] resumeKeyGrabs];
    NSLog(@"ActionSearchSubmenu: Search hidden");
}

- (void)highlightSearchMenuItem
{
    if (!self.appMenuWidget) return;
    
    NSMenu *menu = [self.appMenuWidget currentMenu];
    if (!menu) return;
    
    NSInteger searchIndex = [menu indexOfItemWithTitle:@"Search"];
    if (searchIndex >= 0) {
        NSMenuView *menuView = [menu menuRepresentation];
        if (menuView && [menuView respondsToSelector:@selector(setHighlightedItemIndex:)]) {
            [menuView setHighlightedItemIndex:searchIndex];
            NSLog(@"ActionSearchSubmenu: Search menu item highlighted");
        }
    }
}

- (void)unhighlightSearchMenuItem
{
    if (!self.appMenuWidget) return;
    
    NSMenu *menu = [self.appMenuWidget currentMenu];
    if (!menu) return;
    
    NSMenuView *menuView = [menu menuRepresentation];
    if (menuView && [menuView respondsToSelector:@selector(setHighlightedItemIndex:)]) {
        [menuView setHighlightedItemIndex:-1];
        NSLog(@"ActionSearchSubmenu: Search menu item unhighlighted");
    }
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
    (void)notification;
    if (self.isSearching) {
        [self hideSearch];
    }
}

#pragma mark - Menu Collection

- (void)collectMenuItems
{
    [self.allMenuItems removeAllObjects];
    
    if (!self.appMenuWidget) {
        NSLog(@"ActionSearchSubmenu: No appMenuWidget set");
        return;
    }
    
    NSMenu *currentMenu = [self.appMenuWidget currentMenu];
    if (!currentMenu) {
        NSLog(@"ActionSearchSubmenu: No current menu available");
        return;
    }
    
    NSLog(@"ActionSearchSubmenu: Collecting items from: %@", [currentMenu title]);
    [self collectItemsFromMenu:currentMenu withPath:@""];
    NSLog(@"ActionSearchSubmenu: Collected %lu menu items", (unsigned long)[self.allMenuItems count]);
}

- (void)collectItemsFromMenu:(NSMenu *)menu withPath:(NSString *)path
{
    if (!menu) return;
    
    for (NSMenuItem *item in [menu itemArray]) {
        if ([item isSeparatorItem]) continue;
        
        // Skip the Search item itself
        if ([[item title] isEqualToString:@"Search"]) continue;
        
        NSString *itemPath;
        NSString *itemTitle = [item title];
        
        if ([path length] > 0) {
            itemPath = [NSString stringWithFormat:@"%@ ▸ %@", path, itemTitle];
        } else {
            itemPath = itemTitle;
        }
        
        if ([item hasSubmenu]) {
            [self collectItemsFromMenu:[item submenu] withPath:itemPath];
        } else if ([item action] != nil) {
            ActionSearchResult *result = [[ActionSearchResult alloc] initWithMenuItem:item path:itemPath];
            [self.allMenuItems addObject:result];
        }
    }
}

#pragma mark - Search

- (void)updateSearchResults:(NSString *)searchText
{
    [self.filteredResults removeAllObjects];
    
    if ([searchText length] == 0) {
        [self.resultsMenu removeAllItems];
        return;
    }
    
    NSString *lowercaseSearch = [searchText lowercaseString];
    
    for (ActionSearchResult *result in self.allMenuItems) {
        NSString *lowercaseTitle = [[result title] lowercaseString];
        NSString *lowercasePath = [[result path] lowercaseString];
        
        if ([lowercaseTitle rangeOfString:lowercaseSearch].location != NSNotFound ||
            [lowercasePath rangeOfString:lowercaseSearch].location != NSNotFound) {
            [self.filteredResults addObject:result];
        }
        
        if ([self.filteredResults count] >= kMaxResultsShown) {
            break;
        }
    }
    
    NSLog(@"ActionSearchSubmenu: Search '%@' found %lu results", 
          searchText, (unsigned long)[self.filteredResults count]);
    
    [self showResultsMenu];
}

- (void)showResultsMenu
{
    // Clear old items
    [self.resultsMenu removeAllItems];
    
    if ([self.filteredResults count] == 0) {
        return;
    }
    
    // Add result items with separators between different menus
    NSString *lastMenuName = nil;
    
    for (ActionSearchResult *result in self.filteredResults) {
        // Extract the top-level menu name from the path (e.g., "File" from "File ▸ Open")
        NSArray *pathComponents = [[result path] componentsSeparatedByString:@" ▸ "];
        NSString *currentMenuName = [pathComponents firstObject];
        
        // Add separator if we've moved to a different menu
        if (lastMenuName != nil && ![lastMenuName isEqual:currentMenuName]) {
            [self.resultsMenu addItem:[NSMenuItem separatorItem]];
        }
        lastMenuName = currentMenuName;
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[result path]
                                                      action:@selector(resultMenuItemClicked:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:result];
        [item setEnabled:YES];
        
        // Show keyboard shortcut if available
        if ([[result keyEquivalent] length] > 0) {
            [item setKeyEquivalent:[result keyEquivalent]];
            [item setKeyEquivalentModifierMask:[result modifierMask]];
        }
        
        [self.resultsMenu addItem:item];
    }
    
    // Position menu below the search panel, using the same X coordinate
    NSRect panelFrame = [self.searchFieldPanel frame];
    // Place menu just below the search panel (subtract panel height to move down)
    // menuY = panelOriginY - panelHeight places results menu bottom edge at panel bottom
    CGFloat resultMenuY = panelFrame.origin.y - panelFrame.size.height;
    NSPoint menuLocation = NSMakePoint(self.searchItemX, resultMenuY);
    
    NSLog(@"ActionSearchSubmenu: ===== GAP FIX VERIFICATION =====");
    NSLog(@"ActionSearchSubmenu: Panel frame: origin.y=%.0f, height=%.0f", panelFrame.origin.y, panelFrame.size.height);
    NSLog(@"ActionSearchSubmenu: Results menu Y = panel.originY - panel.height = %.0f - %.0f = %.0f", 
          panelFrame.origin.y, panelFrame.size.height, resultMenuY);
    NSLog(@"ActionSearchSubmenu: Menu positioned at X=%.0f Y=%.0f (panel X=%.0f)", 
          menuLocation.x, menuLocation.y, panelFrame.origin.x);
    NSLog(@"ActionSearchSubmenu: ===== NO GAP: Results flush against search panel =====");
    
    // Pop up the menu
    [self.resultsMenu popUpMenuPositioningItem:nil 
                                    atLocation:menuLocation 
                                        inView:nil];
}

- (void)resultMenuItemClicked:(NSMenuItem *)sender
{
    ActionSearchResult *result = [sender representedObject];
    if (result) {
        NSLog(@"ActionSearchSubmenu: Selected: %@", [result path]);
        [self hideSearch];
        [self executeActionForResult:result];
    }
}

#pragma mark - Action Execution

- (void)executeActionForResult:(ActionSearchResult *)result
{
    if (!result || !result.menuItem) {
        NSLog(@"ActionSearchSubmenu: Cannot execute - no result or menu item");
        return;
    }
    
    NSMenuItem *originalItem = result.menuItem;
    
    NSLog(@"ActionSearchSubmenu: Executing action for: %@", [result path]);
    
    // Try to invoke the menu item's action
    if ([originalItem target] && [originalItem action]) {
        @try {
            [[originalItem target] performSelector:[originalItem action] withObject:originalItem];
        } @catch (NSException *exception) {
            NSLog(@"ActionSearchSubmenu: Exception executing action: %@", exception);
        }
    } else if ([originalItem action]) {
        // No target - try first responder chain
        [NSApp sendAction:[originalItem action] to:nil from:originalItem];
    }
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification
{
    (void)notification;
    NSString *searchString = [(NSTextField *)self.searchField stringValue];
    [self updateSearchResults:searchString];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    (void)control;
    (void)textView;
    
    if (commandSelector == @selector(cancelOperation:)) {
        // Escape key - hide search
        [self hideSearch];
        return YES;
    }
    
    if (commandSelector == @selector(insertNewline:)) {
        // Enter key - execute first result
        if ([self.filteredResults count] > 0) {
            ActionSearchResult *firstResult = [self.filteredResults objectAtIndex:0];
            [self hideSearch];
            [self executeActionForResult:firstResult];
            return YES;
        }
    }
    
    return NO;
}

@end


#pragma mark - ActionSearchController (Legacy support)

@implementation ActionSearchController

@synthesize appMenuWidget = _appMenuWidget;

+ (instancetype)sharedController
{
    pthread_mutex_lock(&_singletonMutex);
    if (_sharedController == nil) {
        _sharedController = [[ActionSearchController alloc] init];
    }
    pthread_mutex_unlock(&_singletonMutex);
    return _sharedController;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.allMenuItems = [NSMutableArray array];
        self.filteredResults = [NSMutableArray array];
    }
    return self;
}

- (void)setAppMenuWidget:(AppMenuWidget *)widget
{
    _appMenuWidget = widget;
    [[ActionSearchSubmenu sharedSubmenu] setAppMenuWidget:widget];
}

- (AppMenuWidget *)appMenuWidget
{
    return _appMenuWidget;
}

- (NSMenu *)currentMenu
{
    return [[ActionSearchSubmenu sharedSubmenu] resultsMenu];
}

- (void)hideSearchPopup
{
    [[ActionSearchSubmenu sharedSubmenu] hideSearch];
}

- (void)toggleSearchPopupAtPoint:(NSPoint)point
{
    (void)point;
    ActionSearchSubmenu *submenu = [ActionSearchSubmenu sharedSubmenu];
    if (submenu.isSearching) {
        [submenu hideSearch];
    } else {
        [submenu showSearchPanel];
    }
}

- (void)searchMenuItemClicked:(id)sender
{
    (void)sender;
    [self toggleSearchPopupAtPoint:NSMakePoint(0, 0)];
}

- (void)searchMenuItemClicked:(id)sender atPoint:(NSPoint)point
{
    (void)sender;
    [self toggleSearchPopupAtPoint:point];
}

- (void)collectMenuItems
{
    [[ActionSearchSubmenu sharedSubmenu] collectMenuItems];
}

- (void)executeActionForResult:(ActionSearchResult *)result
{
    [[ActionSearchSubmenu sharedSubmenu] executeActionForResult:result];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    (void)notification;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    (void)control;
    (void)textView;
    (void)commandSelector;
    return NO;
}

- (void)checkIfClickIsOutside:(NSEvent *)event
{
    ActionSearchSubmenu *submenu = [ActionSearchSubmenu sharedSubmenu];
    if (!submenu.isSearching) return;
    
    NSWindow *eventWindow = [event window];
    if (eventWindow == submenu.searchFieldPanel) return;
    
    [submenu hideSearch];
}

@end
