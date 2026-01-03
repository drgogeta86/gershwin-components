/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import "ActionSearch.h"
#import "AppMenuWidget.h"
#import "X11ShortcutManager.h"
#import <GNUstepGUI/GSTheme.h>
#import <objc/message.h>
#import <pthread.h>

static ActionSearchSubmenu *_sharedSubmenu = nil;
static ActionSearchController *_sharedController = nil;
static pthread_mutex_t _singletonMutex = PTHREAD_MUTEX_INITIALIZER;

static const NSUInteger kMaxResultsShown = 40;
static const CGFloat kPanelWidth = 360.0;
static const CGFloat kPanelHeight = 280.0;
static const CGFloat kFieldHeight = 26.0;
static const CGFloat kFieldInset = 10.0;

#ifndef NSCommandKeyMask
#define NSCommandKeyMask NSEventModifierFlagCommand
#endif
#ifndef NSControlKeyMask
#define NSControlKeyMask NSEventModifierFlagControl
#endif
#ifndef NSAlternateKeyMask
#define NSAlternateKeyMask NSEventModifierFlagOption
#endif
#ifndef NSShiftKeyMask
#define NSShiftKeyMask NSEventModifierFlagShift
#endif

#pragma mark - Lightweight UI helpers

@interface ActionSearchPanel : NSPanel
@end

@implementation ActionSearchPanel

- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }

@end

@interface ActionSearchResult ()
@end

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

@interface ActionSearchSubmenu ()

@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSPanel *searchPanel;
@property (nonatomic, strong) NSTableView *resultsTable;
@property (nonatomic, strong) NSScrollView *resultsScrollView;
@property (nonatomic, strong) NSMutableArray *allMenuItems;
@property (nonatomic, strong) NSMutableArray *filteredResults;
@property (nonatomic, assign) BOOL searching;

@end

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
        self.searching = NO;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark UI setup

- (void)ensurePanel
{
    if (self.searchPanel) {
        return;
    }

    NSRect panelRect = NSMakeRect(0, 0, kPanelWidth, kPanelHeight);
    self.searchPanel = [[ActionSearchPanel alloc] initWithContentRect:panelRect
                                                             styleMask:NSBorderlessWindowMask
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO];
    [self.searchPanel setLevel:NSPopUpMenuWindowLevel];
    [self.searchPanel setHasShadow:YES];
    [self.searchPanel setOpaque:NO];
    [self.searchPanel setHidesOnDeactivate:YES];
    [self.searchPanel setBackgroundColor:[NSColor colorWithCalibratedWhite:0.97 alpha:0.98]];
    [self.searchPanel setReleasedWhenClosed:NO];
    [self.searchPanel setExcludedFromWindowsMenu:YES];

    NSView *content = [[NSView alloc] initWithFrame:panelRect];
    [content setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.searchPanel setContentView:content];

    NSRect fieldFrame = NSMakeRect(kFieldInset,
                                   panelRect.size.height - kFieldInset - kFieldHeight,
                                   panelRect.size.width - 2 * kFieldInset,
                                   kFieldHeight);
    self.searchField = [[NSTextField alloc] initWithFrame:fieldFrame];
    [self.searchField setDelegate:self];
    [self.searchField setAutoresizingMask:NSViewWidthSizable];
    [self.searchField setFont:[NSFont menuFontOfSize:0]];
    [self.searchField setBezeled:YES];
    [self.searchField setBezelStyle:NSTextFieldRoundedBezel];
    [self.searchField setBordered:YES];
    [self.searchField setFocusRingType:NSFocusRingTypeDefault];
    [self.searchField setPlaceholderString:@"Search menus..."];
    [[self.searchPanel contentView] addSubview:self.searchField];

    NSRect tableFrame = NSMakeRect(kFieldInset,
                                   kFieldInset,
                                   panelRect.size.width - 2 * kFieldInset,
                                   panelRect.size.height - kFieldInset * 2 - kFieldHeight - 6);
    self.resultsScrollView = [[NSScrollView alloc] initWithFrame:tableFrame];
    [self.resultsScrollView setHasVerticalScroller:YES];
    [self.resultsScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    self.resultsTable = [[NSTableView alloc] initWithFrame:[[self.resultsScrollView contentView] bounds]];
    [self.resultsTable setDelegate:self];
    [self.resultsTable setDataSource:self];
    [self.resultsTable setHeaderView:nil];
    [self.resultsTable setAllowsEmptySelection:YES];
    [self.resultsTable setAllowsMultipleSelection:NO];
    [self.resultsTable setRowHeight:22.0];
    [self.resultsTable setDoubleAction:@selector(activateSelection:)];
    [self.resultsTable setTarget:self];

    NSTableColumn *titleColumn = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    [titleColumn setEditable:NO];
    [titleColumn setWidth:tableFrame.size.width - 80.0];
    [[titleColumn headerCell] setStringValue:@"Menu Item"];
    [self.resultsTable addTableColumn:titleColumn];

    NSTableColumn *shortcutColumn = [[NSTableColumn alloc] initWithIdentifier:@"shortcut"];
    [shortcutColumn setEditable:NO];
    [shortcutColumn setWidth:70.0];
    [[shortcutColumn headerCell] setStringValue:@"Shortcut"];
    [self.resultsTable addTableColumn:shortcutColumn];

    [self.resultsScrollView setDocumentView:self.resultsTable];
    [[self.searchPanel contentView] addSubview:self.resultsScrollView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidResignActive:)
                                                 name:NSApplicationDidResignActiveNotification
                                               object:nil];
}

#pragma mark Menu item creation

- (NSMenuItem *)createSearchMenuItem
{
    NSMenuItem *searchItem = [[NSMenuItem alloc] initWithTitle:@"Search"
                                                        action:@selector(searchMenuItemTapped:)
                                                 keyEquivalent:@""];
    [searchItem setTarget:self];
    [searchItem setEnabled:YES];
    [searchItem setTag:1001];
    return searchItem;
}

- (void)searchMenuItemTapped:(id)sender
{
    (void)sender;
    [self toggleSearchAnchoredToRect:[self defaultAnchorRect]];
}

- (void)setAppMenuWidget:(AppMenuWidget *)widget
{
    _appMenuWidget = widget;
}

#pragma mark Visibility helpers

- (BOOL)isVisible
{
    return self.searching && self.searchPanel && [self.searchPanel isVisible];
}

- (NSRect)defaultAnchorRect
{
    NSScreen *main = [NSScreen mainScreen];
    if (!main) {
        return NSZeroRect;
    }
    NSRect frame = [main frame];
    CGFloat menuBarHeight = [[GSTheme theme] menuBarHeight];
    CGFloat x = frame.origin.x + frame.size.width - kPanelWidth - 12.0;
    CGFloat y = frame.origin.y + frame.size.height - menuBarHeight;
    return NSMakeRect(x, y, kPanelWidth, menuBarHeight);
}

#pragma mark Showing/Hiding

- (void)toggleSearchAnchoredToRect:(NSRect)anchorRect
{
    if ([self isVisible]) {
        [self hideSearch];
        return;
    }
    [self showSearchAnchoredToRect:anchorRect];
}

- (void)showSearchAnchoredToRect:(NSRect)anchorRect
{
    NSLog(@"ActionSearchSubmenu: showSearchAnchoredToRect anchor incoming: %@", NSStringFromRect(anchorRect));
    [self ensurePanel];

    NSScreen *main = [NSScreen mainScreen];
    NSRect screenFrame = main ? [main frame] : NSZeroRect;

    NSRect anchor = NSIsEmptyRect(anchorRect) ? [self defaultAnchorRect] : anchorRect;
    NSLog(@"ActionSearchSubmenu: using anchor rect: %@", NSStringFromRect(anchor));
    CGFloat x = anchor.size.width > 0 ? anchor.origin.x : (screenFrame.size.width - kPanelWidth - 12.0);
    if (screenFrame.size.width > 0) {
        CGFloat minX = screenFrame.origin.x;
        CGFloat maxX = screenFrame.origin.x + screenFrame.size.width - kPanelWidth;
        x = MIN(MAX(x, minX), maxX);
    }
    CGFloat yBase = anchor.origin.y;
    if (anchor.size.height == 0) {
        yBase = screenFrame.size.height - [[GSTheme theme] menuBarHeight];
    }
    CGFloat y = yBase - kPanelHeight - 2.0;

    NSRect targetFrame = NSMakeRect(x, y, kPanelWidth, kPanelHeight);
    NSLog(@"ActionSearchSubmenu: panel target frame: %@ (screen frame: %@)", NSStringFromRect(targetFrame), NSStringFromRect(screenFrame));
    [self.searchPanel setFrame:targetFrame display:NO];
    [self collectMenuItems];
    NSLog(@"ActionSearchSubmenu: collected %lu items", (unsigned long)[self.allMenuItems count]);
    NSLog(@"ActionSearchSubmenu: about to makeKeyAndOrderFront");
    [self.searchPanel makeKeyAndOrderFront:nil];
    NSLog(@"ActionSearchSubmenu: makeKeyAndOrderFront done");
    self.searching = YES;
    NSLog(@"ActionSearchSubmenu: about to clear and focus field");
    [self.searchField setStringValue:@""];
    [self.searchField becomeFirstResponder];
    NSLog(@"ActionSearchSubmenu: about to updateSearchResults initial");
    [self updateSearchResults:@""];
    NSLog(@"ActionSearchSubmenu: showSearchAnchoredToRect finished");
}

- (void)hideSearch
{
    self.searching = NO;
    if (self.searchPanel && [self.searchPanel isVisible]) {
        [self.searchPanel orderOut:nil];
    }
    [[X11ShortcutManager sharedManager] resumeKeyGrabs];
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
    (void)notification;
    if ([self isVisible]) {
        [self hideSearch];
    }
}

#pragma mark Menu harvesting

- (void)collectMenuItems
{
    [self.allMenuItems removeAllObjects];
    if (!self.appMenuWidget) {
        return;
    }

    NSMenu *currentMenu = [self.appMenuWidget currentMenu];
    if (!currentMenu) {
        return;
    }

    [self collectItemsFromMenu:currentMenu withPath:@""];
}

- (void)collectItemsFromMenu:(NSMenu *)menu withPath:(NSString *)path
{
    if (!menu) {
        return;
    }

    for (NSMenuItem *item in [menu itemArray]) {
        if ([item isSeparatorItem]) {
            continue;
        }
        if ([[item title] isEqualToString:@"Search"]) {
            continue;
        }

        NSString *itemPath = [path length] > 0 ? [NSString stringWithFormat:@"%@ ▸ %@", path, [item title]] : [item title];

        if ([item hasSubmenu]) {
            [self collectItemsFromMenu:[item submenu] withPath:itemPath];
        } else if ([item action] != nil) {
            ActionSearchResult *result = [[ActionSearchResult alloc] initWithMenuItem:item path:itemPath];
            [self.allMenuItems addObject:result];
        }
    }
}

#pragma mark Filtering

- (void)updateSearchResults:(NSString *)searchText
{
    NSLog(@"ActionSearchSubmenu: updateSearchResults text='%@'", searchText);
    [self.filteredResults removeAllObjects];

    if ([searchText length] == 0) {
        [self.resultsTable reloadData];
        return;
    }

    NSString *needle = [searchText lowercaseString];
    for (ActionSearchResult *result in self.allMenuItems) {
        NSString *title = [[result title] lowercaseString];
        NSString *path = [[result path] lowercaseString];
        if ([title rangeOfString:needle].location != NSNotFound ||
            [path rangeOfString:needle].location != NSNotFound) {
            [self.filteredResults addObject:result];
        }
        if ([self.filteredResults count] >= kMaxResultsShown) {
            break;
        }
    }
    NSLog(@"ActionSearchSubmenu: filtered to %lu results", (unsigned long)[self.filteredResults count]);
    [self.resultsTable reloadData];
    if ([self.filteredResults count] > 0) {
        [self.resultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.resultsTable scrollRowToVisible:0];
    } else {
        [self.resultsTable deselectAll:nil];
    }
}

- (NSString *)shortcutStringForResult:(ActionSearchResult *)result
{
    if (!result || [[result keyEquivalent] length] == 0) {
        return @"";
    }

    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger mask = [result modifierMask];
    if (mask & NSCommandKeyMask) {
        [parts addObject:@"Cmd"];
    }
    if (mask & NSControlKeyMask) {
        [parts addObject:@"Ctrl"];
    }
    if (mask & NSAlternateKeyMask) {
        [parts addObject:@"Alt"];
    }
    if (mask & NSShiftKeyMask) {
        [parts addObject:@"Shift"];
    }

    [parts addObject:[[result keyEquivalent] uppercaseString]];
    return [parts componentsJoinedByString:@"+"];
}

#pragma mark Table delegate/data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    (void)tableView;
    return (NSInteger)[self.filteredResults count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    (void)tableView;
    if (row < 0 || (NSUInteger)row >= [self.filteredResults count]) {
        return @"";
    }

    ActionSearchResult *result = [self.filteredResults objectAtIndex:(NSUInteger)row];
    if ([[tableColumn identifier] isEqualToString:@"shortcut"]) {
        return [self shortcutStringForResult:result];
    }
    return [result path];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    (void)notification;
}

- (void)activateSelection:(id)sender
{
    (void)sender;
    NSInteger row = [self.resultsTable selectedRow];
    NSLog(@"ActionSearchSubmenu: activateSelection row=%ld", (long)row);
    if (row < 0 || (NSUInteger)row >= [self.filteredResults count]) {
        return;
    }
    ActionSearchResult *result = [self.filteredResults objectAtIndex:(NSUInteger)row];
    [self hideSearch];
    [self executeActionForResult:result];
}

#pragma mark Action execution

- (void)executeActionForResult:(ActionSearchResult *)result
{
    if (!result || !result.menuItem) {
        return;
    }

    NSLog(@"ActionSearchSubmenu: executing path='%@' title='%@'", [result path], [result title]);
    NSMenuItem *originalItem = result.menuItem;
    if ([originalItem target] && [originalItem action]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [[originalItem target] performSelector:[originalItem action] withObject:originalItem];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"ActionSearchSubmenu: Exception executing action: %@", exception);
        }
    } else if ([originalItem action]) {
        [NSApp sendAction:[originalItem action] to:nil from:originalItem];
    }
}

#pragma mark NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification
{
    (void)notification;
    [self updateSearchResults:[self.searchField stringValue]];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    (void)control;
    (void)textView;

    if (commandSelector == @selector(cancelOperation:)) {
        [self hideSearch];
        return YES;
    }

    if (commandSelector == @selector(insertNewline:)) {
        [self activateSelection:nil];
        return YES;
    }

    if (commandSelector == @selector(moveDown:)) {
        NSLog(@"ActionSearchSubmenu: moveDown");
        [self moveSelectionBy:1];
        return YES;
    }

    if (commandSelector == @selector(moveUp:)) {
        NSLog(@"ActionSearchSubmenu: moveUp");
        [self moveSelectionBy:-1];
        return YES;
    }

    return NO;
}

- (void)moveSelectionBy:(NSInteger)delta
{
    if ([self.filteredResults count] == 0) {
        return;
    }
    NSInteger current = [self.resultsTable selectedRow];
    NSLog(@"ActionSearchSubmenu: moveSelectionBy delta=%ld current=%ld", (long)delta, (long)current);
    if (current < 0) {
        current = 0;
    }
    NSInteger next = current + delta;
    if (next < 0) {
        next = 0;
    }
    if (next >= (NSInteger)[self.filteredResults count]) {
        next = (NSInteger)[self.filteredResults count] - 1;
    }
    [self.resultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)next] byExtendingSelection:NO];
    [self.resultsTable scrollRowToVisible:next];
}

@end


#pragma mark - ActionSearchController (legacy wrapper)

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

- (void)hideSearchPopup
{
    [[ActionSearchSubmenu sharedSubmenu] hideSearch];
}

- (void)toggleSearchPopupAtPoint:(NSPoint)point
{
    NSRect anchor = NSMakeRect(point.x, point.y, 1, [[GSTheme theme] menuBarHeight]);
    [[ActionSearchSubmenu sharedSubmenu] toggleSearchAnchoredToRect:anchor];
}

- (void)collectMenuItems
{
    [[ActionSearchSubmenu sharedSubmenu] collectMenuItems];
}

- (void)executeActionForResult:(ActionSearchResult *)result
{
    [[ActionSearchSubmenu sharedSubmenu] executeActionForResult:result];
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

- (void)checkIfClickIsOutside:(NSEvent *)event
{
    ActionSearchSubmenu *submenu = [ActionSearchSubmenu sharedSubmenu];
    if (![submenu isVisible]) {
        return;
    }

    NSWindow *eventWindow = [event window];
    if (eventWindow == [submenu searchPanel]) {
        return;
    }

    [submenu hideSearch];
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

@end
