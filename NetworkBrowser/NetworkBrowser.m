/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "NetworkBrowser.h"
#import "ServiceListView.h"
#import "ServiceDetailsView.h"

@implementation NetworkBrowser

- (id)init
{
  self = [super init];
  if (self)
    {
      services = [[NSMutableArray alloc] init];
      serviceBrowser = nil;
    }
  return self;
}

- (void)dealloc
{
  if (serviceBrowser)
    {
      [serviceBrowser stop];
      RELEASE(serviceBrowser);
    }
  RELEASE(services);
  RELEASE(window);
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  /* Check if mDNS-SD support is available */
  Class netServiceBrowserClass = NSClassFromString(@"NSNetServiceBrowser");
  if (!netServiceBrowserClass)
    {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert setAlertStyle: NSWarningAlertStyle];
      [alert setMessageText: @"mDNS-SD Support Not Available"];
      [alert setInformativeText: 
        @"This GNUstep installation was not built with mDNS-SD (DNS-SD) support. "
        @"Network service discovery will not work.\n\n"
        @"To enable this feature, you need to:\n"
        @"1. Install libdns_sd development files (libavahi-compat-libdnssd-dev on Debian)\n"
        @"2. Rebuild GNUstep with DNS-SD support\n\n"
        @"The application will continue but service discovery is unavailable."];
      [alert addButtonWithTitle: @"Continue"];
      [alert addButtonWithTitle: @"Quit"];
      
      NSInteger result = [alert runModal];
      [alert release];
      
      if (result != NSAlertFirstButtonReturn)
        {
          [NSApp terminate: nil];
          return;
        }
    }
  
  NSRect windowFrame = NSMakeRect(100, 100, 800, 600);
  
  /* Create main window */
  window = [[NSWindow alloc] 
    initWithContentRect: windowFrame
    styleMask: (NSTitledWindowMask | NSClosableWindowMask | 
                NSMiniaturizableWindowMask | NSResizableWindowMask)
    backing: NSBackingStoreBuffered 
    defer: NO];
  
  [window setTitle: @"Network Browser"];
  [window setMinSize: NSMakeSize(600, 400)];
  [window setDelegate: self];
  
  /* Create split view */
  splitView = [[NSSplitView alloc] initWithFrame: [[window contentView] bounds]];
  [splitView setVertical: YES];
  [splitView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  
  /* Create list view (left pane) */
  NSRect leftFrame = NSMakeRect(0, 0, 250, 600);
  listView = [[ServiceListView alloc] initWithFrame: leftFrame];
  
  /* Create details view (right pane) */
  NSRect rightFrame = NSMakeRect(250, 0, 550, 600);
  detailsView = [[ServiceDetailsView alloc] initWithFrame: rightFrame];
  
  [listView setDetailsView: detailsView];
  
  /* Add subviews to split view */
  [splitView addSubview: listView];
  [splitView addSubview: detailsView];
  
  /* Set split view as content view */
  [window setContentView: splitView];
  
  [window makeKeyAndOrderFront: nil];
  
  /* Start browsing for services */
  [self startServiceBrowsing];
}

- (void)startServiceBrowsing
{
  serviceBrowser = [[NSNetServiceBrowser alloc] init];
  [serviceBrowser setDelegate: self];
  [serviceBrowser searchForServicesOfType: @"_http._tcp" 
                                  inDomain: @"local"];
}

/* NSNetServiceBrowserDelegate methods */

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
  NSLog(@"Starting to search for network services...");
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
  NSLog(@"Stopped searching for network services");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
           didFindService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing
{
  NSLog(@"Found service: %@", [aNetService name]);
  [aNetService setDelegate: self];
  [aNetService resolve];
  [services addObject: aNetService];
  [listView addService: aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
         didRemoveService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing
{
  NSLog(@"Service removed: %@", [aNetService name]);
  [services removeObject: aNetService];
  [listView removeService: aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
 didNotSearch:(NSDictionary *)errorDict
{
  NSLog(@"Error searching for services: %@", errorDict);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApp
{
  return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if ([aNotification object] == window)
    {
      [NSApp terminate: self];
    }
}

@end
