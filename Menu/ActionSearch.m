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

// Singleton instance
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


#pragma mark - ActionSearchController

@implementation ActionSearchController

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
        
        [self createSearchPanel];
        [self createResultsMenu];
    }
    return self;
}

- (void)createSearchPanel
{
    // Create a small panel just for the search field
    // Use borderless style - keyboard routing is handled in MenuApplication.sendEvent:
    NSRect panelRect = NSMakeRect(0, 0, kSearchFieldWidth + 16, kSearchFieldHeight + 12);
    
    self.searchPanel = [[ActionSearchPanel alloc] initWithContentRect:panelRect
                                                  styleMask:NSBorderlessWindowMask
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    [self.searchPanel setLevel:NSPopUpMenuWindowLevel];
    [self.searchPanel setHasShadow:YES];
    [self.searchPanel setOpaque:YES];
    [self.searchPanel setBackgroundColor:[[GSTheme theme] menuBackgroundColor]];
    [self.searchPanel setBecomesKeyOnlyIfNeeded:NO];
    [self.searchPanel setReleasedWhenClosed:NO];
    
    // Create search field
    self.searchField = [[NSTextField alloc] initWithFrame:
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
    
    [[self.searchPanel contentView] addSubview:self.searchField];
    
    NSLog(@"ActionSearchController: Created search panel");
}

- (void)createResultsMenu
{
    self.resultsMenu = [[NSMenu alloc] initWithTitle:@"Search Results"];
    [self.resultsMenu setAutoenablesItems:NO];
    
    NSLog(@"ActionSearchController: Created results menu");
}

- (void)setAppMenuWidget:(AppMenuWidget *)widget
{
    _appMenuWidget = widget;
}

- (void)showSearchPopupAtPoint:(NSPoint)point
{
    // Suspend global key grabs
    [[X11ShortcutManager sharedManager] suspendKeyGrabs];
    
    // Collect menu items
    [self collectMenuItems];
    
    // Reset state
    [self.searchField setStringValue:@""];
    [self.filteredResults removeAllObjects];
    
    // Store location for showing results menu
    self.popupLocation = point;
    
    // Position panel below click point
    NSRect panelFrame = [self.searchPanel frame];
    panelFrame.origin.x = point.x - panelFrame.size.width / 2;
    panelFrame.origin.y = point.y - panelFrame.size.height;
    
    // Keep on screen
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    if (NSMaxX(panelFrame) > NSMaxX(screenFrame)) {
        panelFrame.origin.x = NSMaxX(screenFrame) - panelFrame.size.width - 10;
    }
    if (panelFrame.origin.x < screenFrame.origin.x) {
        panelFrame.origin.x = screenFrame.origin.x + 10;
    }
    
    [self.searchPanel setFrame:panelFrame display:YES];
    [self.searchPanel makeKeyAndOrderFront:nil];
    
    // Focus the search field
    [self.searchPanel makeFirstResponder:self.searchField];
    
    NSLog(@"ActionSearchController: Showing search popup at %.0f, %.0f", point.x, point.y);
}

- (void)hideSearchPopup
{
    [self.searchPanel orderOut:nil];
    [[X11ShortcutManager sharedManager] resumeKeyGrabs];
    NSLog(@"ActionSearchController: Hiding search popup");
}

- (void)toggleSearchPopupAtPoint:(NSPoint)point
{
    if ([self.searchPanel isVisible]) {
        [self hideSearchPopup];
    } else {
        [self showSearchPopupAtPoint:point];
    }
}

#pragma mark - Menu Collection

- (void)collectMenuItems
{
    [self.allMenuItems removeAllObjects];
    
    if (!self.appMenuWidget) {
        NSLog(@"ActionSearchController: No appMenuWidget set");
        return;
    }
    
    NSMenu *currentMenu = [self.appMenuWidget currentMenu];
    if (!currentMenu) {
        NSLog(@"ActionSearchController: No current menu available");
        return;
    }
    
    NSLog(@"ActionSearchController: Collecting items from: %@", [currentMenu title]);
    [self collectItemsFromMenu:currentMenu withPath:@""];
    NSLog(@"ActionSearchController: Collected %lu menu items", (unsigned long)[self.allMenuItems count]);
}

- (void)collectItemsFromMenu:(NSMenu *)menu withPath:(NSString *)path
{
    if (!menu) return;
    
    for (NSMenuItem *item in [menu itemArray]) {
        if ([item isSeparatorItem]) continue;
        
        NSString *itemPath;
        NSString *itemTitle = [item title];
        
        // Append submenu indicator if this item has a submenu
        if ([item hasSubmenu]) {
            itemTitle = [NSString stringWithFormat:@"%@ ▷", itemTitle];
        }
        
        if ([path length] > 0) {
            itemPath = [NSString stringWithFormat:@"%@ %@", path, itemTitle];
        } else {
            itemPath = itemTitle;
        }
        
        if ([item hasSubmenu]) {
            [self collectItemsFromMenu:[item submenu] withPath:itemPath];
        } else if ([item action] != nil) {
            // Include both enabled and disabled items, but track enabled state
            ActionSearchResult *result = [[ActionSearchResult alloc] initWithMenuItem:item path:itemPath];
            [self.allMenuItems addObject:result];
        }
    }
}

#pragma mark - Search

- (void)searchWithString:(NSString *)searchString
{
    [self.filteredResults removeAllObjects];
    
    if ([searchString length] == 0) {
        return;
    }
    
    NSString *lowercaseSearch = [searchString lowercaseString];
    
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
    
    NSLog(@"ActionSearchController: Search '%@' found %lu results", 
          searchString, (unsigned long)[self.filteredResults count]);
    
    [self showResultsMenu];
}

- (void)showResultsMenu
{
    // Clear old items
    [self.resultsMenu removeAllItems];
    
    if ([self.filteredResults count] == 0) {
        return;
    }
    
    // Add result items, with separators between different top-level menus
    NSString *previousTopLevelMenu = @"";
    for (NSUInteger i = 0; i < [self.filteredResults count]; i++) {
        ActionSearchResult *result = [self.filteredResults objectAtIndex:i];
        
        // Extract top-level menu (first component of the path)
        NSString *topLevelMenu = result.path;
        NSRange firstSpace = [topLevelMenu rangeOfString:@" "];
        if (firstSpace.location != NSNotFound) {
            topLevelMenu = [topLevelMenu substringToIndex:firstSpace.location];
        }
        // Remove submenu indicator if present
        topLevelMenu = [topLevelMenu stringByReplacingOccurrencesOfString:@" ▷" withString:@""];
        
        // Add separator if top-level menu changed (but not before the first item)
        if (i > 0 && ![topLevelMenu isEqual:previousTopLevelMenu]) {
            [self.resultsMenu addItem:[NSMenuItem separatorItem]];
        }
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[result path]
                                                      action:@selector(resultMenuItemClicked:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:result];
        // Respect the enabled state from the original menu item
        [item setEnabled:[result enabled]];
        
        // Show keyboard shortcut if available
        if ([[result keyEquivalent] length] > 0) {
            [item setKeyEquivalent:[result keyEquivalent]];
            [item setKeyEquivalentModifierMask:[result modifierMask]];
        }
        
        [self.resultsMenu addItem:item];
        previousTopLevelMenu = topLevelMenu;
    }
    
    // Position menu below the search panel
    NSRect panelFrame = [self.searchPanel frame];
    NSPoint menuLocation = NSMakePoint(panelFrame.origin.x, panelFrame.origin.y);
    
    // Pop up the menu
    [self.resultsMenu popUpMenuPositioningItem:nil 
                                    atLocation:menuLocation 
                                        inView:nil];
}

- (void)resultMenuItemClicked:(NSMenuItem *)sender
{
    ActionSearchResult *result = [sender representedObject];
    if (result) {
        NSLog(@"ActionSearchController: Selected: %@", [result path]);
        [self hideSearchPopup];
        [self executeActionForResult:result];
    }
}

#pragma mark - Action Execution

- (void)executeActionForResult:(ActionSearchResult *)result
{
    if (!result || !result.menuItem) {
        NSLog(@"ActionSearchController: Cannot execute - no result or menu item");
        return;
    }
    
    NSMenuItem *originalItem = result.menuItem;
    
    NSLog(@"ActionSearchController: Executing action for: %@", [result path]);
    
    // Try to invoke the menu item's action
    if ([originalItem target] && [originalItem action]) {
        @try {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [[originalItem target] performSelector:[originalItem action] withObject:originalItem];
            #pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"ActionSearchController: Exception executing action: %@", exception);
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
    NSString *searchString = [self.searchField stringValue];
    [self searchWithString:searchString];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    (void)control;
    (void)textView;
    
    if (commandSelector == @selector(cancelOperation:)) {
        // Escape key - hide popup
        [self hideSearchPopup];
        return YES;
    }
    
    return NO;
}

@end


#pragma mark - ActionSearchMenuView

@implementation ActionSearchMenuView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        // Nothing special needed
    }
    return self;
}

- (void)setAppMenuWidget:(AppMenuWidget *)widget
{
    _appMenuWidget = widget;
    [[ActionSearchController sharedController] setAppMenuWidget:widget];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    
    // Draw search icon (magnifying glass)
    NSString *searchIcon = @"🔍";
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor darkGrayColor]
    };
    
    NSSize iconSize = [searchIcon sizeWithAttributes:attrs];
    NSPoint iconPoint = NSMakePoint((self.bounds.size.width - iconSize.width) / 2,
                                    (self.bounds.size.height - iconSize.height) / 2);
    [searchIcon drawAtPoint:iconPoint withAttributes:attrs];
}

- (void)mouseDown:(NSEvent *)event
{
    (void)event;
    
    // Get click location in screen coordinates
    NSPoint locationInView = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint screenLocation = [[self window] convertBaseToScreen:
        [self convertPoint:locationInView toView:nil]];
    
    [[ActionSearchController sharedController] toggleSearchPopupAtPoint:screenLocation];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    (void)event;
    return YES;
}

@end
