/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef NETWORKBROWSER_H
#define NETWORKBROWSER_H

#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSView.h>
#import <AppKit/NSSplitView.h>
#import <Foundation/NSNetServices.h>

@class ServiceListView;
@class ServiceDetailsView;

@interface NetworkBrowser : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
  NSWindow *window;
  NSSplitView *splitView;
  ServiceListView *listView;
  ServiceDetailsView *detailsView;
  NSNetServiceBrowser *serviceBrowser;
  NSMutableArray *services;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApp;
- (void)windowWillClose:(NSNotification *)aNotification;

@end

#endif // NETWORKBROWSER_H
