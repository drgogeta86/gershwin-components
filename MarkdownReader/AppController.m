/*
 * AppController.m
 *
 * MarkdownReader Application Delegate
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "AppController.h"
#import "../MarkdownTextConverter/MarkdownConsumer.h"
#import <AppKit/AppKit.h>

@implementation AppController

- (void) applicationWillFinishLaunching: (NSNotification *)notifier
{
  NSMenu *mainMenu = [NSApp mainMenu];
  if (!mainMenu)
    {
      mainMenu = [[NSMenu alloc] initWithTitle: @"MainMenu"];
      [NSApp setMainMenu: mainMenu];
    }

  NSString *appName = [[NSProcessInfo processInfo] processName];

  // --- Application menu (AppName) ---
  NSMenu *appMenu = nil;
  NSMenuItem *appItem = nil;

  // If an app-like menu already exists, reuse it to avoid duplicates
  for (NSMenuItem *mi in [mainMenu itemArray])
    {
      if ([[mi title] isEqualToString: appName] && [mi submenu] != nil)
        {
          // Prefer the existing item if it contains an About entry
          NSMenu *sub = [mi submenu];
          for (NSMenuItem *si in [sub itemArray])
            {
              if (si.action == @selector(orderFrontStandardAboutPanel:))
                {
                  appMenu = sub;
                  appItem = mi;
                  break;
                }
            }
          if (appMenu) break;
        }
    }

  if (!appMenu)
    {
      appMenu = [[NSMenu alloc] initWithTitle: appName];
      appItem = (NSMenuItem *)[mainMenu addItemWithTitle: appName action: NULL keyEquivalent: @""];
      [mainMenu setSubmenu: appMenu forItem: appItem];
    }

  [appMenu addItemWithTitle: [NSString stringWithFormat:@"About %@...", appName]
                     action: @selector(orderFrontStandardAboutPanel:)
              keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Preferences..."
                     action: @selector(showPreferences:)
              keyEquivalent: @","];
  [appMenu addItem: [NSMenuItem separatorItem]];

  NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle: @"Services"];
  NSMenuItem *servicesItem = (NSMenuItem *)[appMenu addItemWithTitle: @"Services" action: NULL keyEquivalent: @""];
  [appMenu setSubmenu: servicesMenu forItem: servicesItem];
  RELEASE(servicesMenu);

  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: [NSString stringWithFormat:@"Hide %@", appName]
                     action: @selector(hide:)
              keyEquivalent: @"h"];
  [appMenu addItemWithTitle: @"Hide Others"
                     action: @selector(hideOtherApplications:)
              keyEquivalent: @"H"];
  [appMenu addItemWithTitle: @"Show All"
                     action: @selector(unhideAllApplications:)
              keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Quit"
                     action: @selector(terminate:)
              keyEquivalent: @"q"];

  // Remove duplicate top-level items named after the app (keep the appItem we added)
  NSArray *items = [[mainMenu itemArray] copy];
  for (NSMenuItem *mi in items)
    {
      if (mi != appItem && [[mi title] isEqualToString: appName])
        {
          [mainMenu removeItem: mi];
        }
    }
  [items release];

  // --- File menu ---
  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle: @"File"];
  NSMenuItem *fileItem = (NSMenuItem *)[mainMenu addItemWithTitle: @"File" action: NULL keyEquivalent: @""];
  [mainMenu setSubmenu: fileMenu forItem: fileItem];

  // Open multiple files
  [fileMenu addItemWithTitle: @"Open..."
                      action: @selector(openDocument:)
               keyEquivalent: @"o"];

  // Close the frontmost window
  [fileMenu addItemWithTitle: @"Close"
                      action: @selector(performClose:)
               keyEquivalent: @"w"];

  // Close all document windows (Option-Command-W)
  NSMenuItem *closeAllItem = [[NSMenuItem alloc] initWithTitle:@"Close All"
                                                        action:@selector(closeAllWindows:)
                                                 keyEquivalent:@"w"];
  // Use Command + Option modifier for Close All
  [closeAllItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagOption)];
  [fileMenu addItem:closeAllItem];
  [closeAllItem release];

  [fileMenu addItem: [NSMenuItem separatorItem]];
  
  // --- Edit menu ---
  NSMenu *editMenu = [[NSMenu alloc] initWithTitle: @"Edit"];
  NSMenuItem *editItem = (NSMenuItem *)[mainMenu addItemWithTitle: @"Edit" action: NULL keyEquivalent: @""];
  [mainMenu setSubmenu: editMenu forItem: editItem];

  [editMenu addItemWithTitle: @"Undo"
                      action: @selector(undo:)
               keyEquivalent: @"z"];
  [editMenu addItemWithTitle: @"Redo"
                      action: @selector(redo:)
               keyEquivalent: @"Z"];
  [editMenu addItem: [NSMenuItem separatorItem]];
  [editMenu addItemWithTitle: @"Cut"
                      action: @selector(cut:)
               keyEquivalent: @"x"];
  [editMenu addItemWithTitle: @"Copy"
                      action: @selector(copy:)
               keyEquivalent: @"c"];
  [editMenu addItemWithTitle: @"Paste"
                      action: @selector(paste:)
               keyEquivalent: @"v"];
  [editMenu addItemWithTitle: @"Select All"
                      action: @selector(selectAll:)
               keyEquivalent: @"a"];
  [editMenu addItem: [NSMenuItem separatorItem]];
  [editMenu addItemWithTitle: @"Find..."
                      action: @selector(performFindPanelAction:)
               keyEquivalent: @"f"];

  // --- Window menu ---
  NSMenu *windowMenu = [[NSMenu alloc] initWithTitle: @"Window"];
  NSMenuItem *windowItem = (NSMenuItem *)[mainMenu addItemWithTitle: @"Window" action: NULL keyEquivalent: @""];
  [mainMenu setSubmenu: windowMenu forItem: windowItem];

  [windowMenu addItemWithTitle: @"Minimize"
                        action: @selector(performMiniaturize:)
                 keyEquivalent: @"m"];
  [windowMenu addItemWithTitle: @"Zoom"
                        action: @selector(performZoom:)
                 keyEquivalent: @""];
  [windowMenu addItem: [NSMenuItem separatorItem]];
  [windowMenu addItemWithTitle: @"Bring All to Front"
                        action: @selector(arrangeInFront:)
                 keyEquivalent: @""];

  // Clean up
  RELEASE(appMenu);
  RELEASE(fileMenu);
  RELEASE(editMenu);
  RELEASE(windowMenu);
  RELEASE(mainMenu);
}

- (void) applicationDidFinishLaunching: (NSNotification *)notifier
{
  // Attempt to open a document immediately if none are open
  // We use performSelector:withObject:afterDelay: to let the event loop start first
  [self performSelector:@selector(openDocument:) withObject:nil afterDelay:0.1];

  // Some platforms may add a disabled app-name top menu entry after launch; remove any spurious instances
  [self performSelector:@selector(_removeSpuriousAppMenuItems) withObject:nil afterDelay:0.25];

  // Also remove spurious items when the app becomes active or the menu updates
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_removeSpuriousAppMenuItems)
                                               name:NSApplicationDidBecomeActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_removeSpuriousAppMenuItems)
                                               name:NSApplicationDidUpdateNotification
                                             object:nil];
}

- (void) openDocument: (id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setAllowsMultipleSelection: YES];
  [panel setCanChooseDirectories: NO];
  [panel setCanChooseFiles: YES];
  
  if ([panel runModalForDirectory: nil file: nil types: @[@"md", @"markdown", @"txt"]] == NSOKButton)
    {
      NSArray *files = [panel filenames];
      for (NSString *filename in files)
        {
          [self application: NSApp openFile: filename];
        }
    }
}

- (BOOL) application: (NSApplication *)app openFile: (NSString *)filename
{
  NSData *data = [NSData dataWithContentsOfFile: filename];
  if (!data)
    {
      NSRunAlertPanel(@"Error", @"Could not read file %@", @"OK", nil, nil, filename);
      return NO;
    }

  NSAttributedString *content = [MarkdownConsumer parseData: data
                                                    options: nil
                                         documentAttributes: NULL
                                                      error: NULL
                                                      class: [NSAttributedString class]];

  if (!content)
    {
      NSRunAlertPanel(@"Error", @"Could not parse markdown in %@", @"OK", nil, nil, filename);
      return NO;
    }

  NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 600, 800)
                                                 styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                                                   backing: NSBackingStoreBuffered
                                                     defer: NO];
  [window setTitle: [filename lastPathComponent]];

  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame: [[window contentView] bounds]];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setHasHorizontalScroller: NO];
  [scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [scrollView setBorderType: NSNoBorder];

  NSTextView *textView = [[NSTextView alloc] initWithFrame: [[scrollView contentView] bounds]];
  [textView setMinSize: NSMakeSize(0.0, [[scrollView contentView] bounds].size.height)];
  [textView setMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];
  [textView setVerticallyResizable: YES];
  [textView setHorizontallyResizable: NO];
  [textView setAutoresizingMask: NSViewWidthSizable];
  [[textView textContainer] setContainerSize: NSMakeSize([[scrollView contentView] bounds].size.width, FLT_MAX)];
  [[textView textContainer] setWidthTracksTextView: YES];
  
  // Set the attributed string
  [[textView textStorage] setAttributedString: content];
  [textView setEditable: NO];

  [scrollView setDocumentView: textView];
  [window setContentView: scrollView];
  
  RELEASE(textView);
  RELEASE(scrollView);
  
  [window makeKeyAndOrderFront: self];
  // Ensure the window object is released when closed so we don't leak
  [window setReleasedWhenClosed: YES];

  return YES;
}

- (void) showAboutPanel: (id)sender
{
  [NSApp orderFrontStandardAboutPanel: sender];
}

- (void) _removeSpuriousAppMenuItems
{
  NSMenu *mainMenu = [NSApp mainMenu];
  if (!mainMenu) return;
  NSArray *items = [[mainMenu itemArray] copy];
  NSString *appName = [[NSProcessInfo processInfo] processName];
  for (NSMenuItem *mi in items)
    {
      if (![[mi title] isEqualToString: appName])
        continue;
      // Keep the app menu that contains the standard About item; remove others
      NSMenu *sub = [mi submenu];
      BOOL keep = NO;
      if (sub)
        {
          for (NSMenuItem *si in [sub itemArray])
            {
              if (si.action == @selector(orderFrontStandardAboutPanel:))
                {
                  keep = YES;
                  break;
                }
            }
        }
      if (!keep)
        {
          [mainMenu removeItem: mi];
        }
    }
  [items release];
}

- (void) showPreferences: (id)sender
{
  NSAlert *alert = [NSAlert alertWithMessageText:@"Preferences"
                                   defaultButton:@"OK"
                                 alternateButton:nil
                                     otherButton:nil
                       informativeTextWithFormat:@"No preferences available yet."];
  [alert runModal];
}

- (IBAction) closeAllWindows: (id)sender
{
  for (NSWindow *w in [NSApp windows])
    {
      // Only close standard document windows
      if (![w isKindOfClass: [NSPanel class]])
        [w performClose: sender];
    }
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
  // Do not terminate the app when the last window closes; keep the app running
  return NO;
}

@end
