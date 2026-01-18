/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "GNUStepMenuActionHandler.h"
#import "GNUStepMenuIPC.h"
#import <Foundation/NSConnection.h>
#import <AppKit/NSMenuItem.h>

// Static cache of connections to GNUstep clients (keyed by clientName)
static NSMutableDictionary *connectionCache = nil;
static NSLock *connectionCacheLock = nil;

@implementation GNUStepMenuActionHandler

+ (void)initialize
{
    if (self == [GNUStepMenuActionHandler class]) {
        connectionCache = [[NSMutableDictionary alloc] init];
        connectionCacheLock = [[NSLock alloc] init];
    }
}

+ (NSConnection *)_getCachedConnectionForClient:(NSString *)clientName
{
    [connectionCacheLock lock];
    NSConnection *connection = [connectionCache objectForKey:clientName];
    
    // Test if connection is still valid
    if (connection && ![connection isValid]) {
        NSLog(@"GNUStepMenuActionHandler: Cached connection for %@ is invalid, removing", clientName);
        [connectionCache removeObjectForKey:clientName];
        connection = nil;
    }
    
    if (!connection) {
        NSLog(@"GNUStepMenuActionHandler: Creating new connection to client %@", clientName);
        connection = [NSConnection connectionWithRegisteredName:clientName host:nil];
        if (connection) {
            [connectionCache setObject:connection forKey:clientName];
            NSLog(@"GNUStepMenuActionHandler: Cached connection for %@", clientName);
        }
    } else {
        NSLog(@"GNUStepMenuActionHandler: Reusing cached connection for %@", clientName);
    }
    
    [connectionCacheLock unlock];
    return connection;
}

+ (void)performMenuAction:(id)sender
{
    NSLog(@"GNUStepMenuActionHandler: performMenuAction called with sender: %@", sender);
    
    if (![sender isKindOfClass:[NSMenuItem class]]) {
        NSLog(@"GNUStepMenuActionHandler: Sender is not an NSMenuItem");
        return;
    }

    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSDictionary *info = [menuItem representedObject];
    
    NSLog(@"GNUStepMenuActionHandler: Menu item '%@' representedObject: %@", [menuItem title], info);
    
    if (![info isKindOfClass:[NSDictionary class]]) {
        NSLog(@"GNUStepMenuActionHandler: Missing action metadata for item '%@'", [menuItem title]);
        return;
    }

    NSString *clientName = [info objectForKey:@"clientName"];
    NSNumber *windowId = [info objectForKey:@"windowId"];
    NSArray *indexPath = [info objectForKey:@"indexPath"];

    NSLog(@"GNUStepMenuActionHandler: Extracted - clientName: %@, windowId: %@, indexPath: %@", clientName, windowId, indexPath);

    if (!clientName || !windowId || !indexPath) {
        NSLog(@"GNUStepMenuActionHandler: Invalid action metadata for item '%@'", [menuItem title]);
        return;
    }

    // Execute the IPC callback on the main thread to keep the NSConnection stable
    // The oneway call is non-blocking, so this should not freeze Menu.app
    NSDictionary *backgroundInfo = @{ @"clientName": clientName, @"windowId": windowId, @"indexPath": indexPath, @"menuItemTitle": [menuItem title] };
    [self _performMenuActionInBackground:backgroundInfo];
}

+ (void)_performMenuActionInBackground:(NSDictionary *)info
{
    NSString *clientName = info[@"clientName"];
    NSNumber *windowId = info[@"windowId"];
    NSArray *indexPath = info[@"indexPath"];
    NSString *menuItemTitle = info[@"menuItemTitle"];

    NSLog(@"GNUStepMenuActionHandler: Main thread - getting connection to client %@", clientName);

    NSConnection *connection = [self _getCachedConnectionForClient:clientName];
    if (!connection) {
        NSLog(@"GNUStepMenuActionHandler: Unable to connect to GNUstep menu client %@", clientName);
        return;
    }
    
    NSLog(@"GNUStepMenuActionHandler: Have connection to client %@", clientName);

    id proxy = [connection rootProxy];
    if (!proxy) {
        NSLog(@"GNUStepMenuActionHandler: No root proxy for GNUstep menu client %@", clientName);
        return;
    }

    [proxy setProtocolForProxy:@protocol(GSGNUstepMenuClient)];
    
    NSLog(@"GNUStepMenuActionHandler: Proxy protocol set, about to call activateMenuItemAtPath");
    NSLog(@"GNUStepMenuActionHandler: Proxy responds to selector: %d", [proxy respondsToSelector:@selector(activateMenuItemAtPath:forWindow:)]);

    @try {
        // The oneway modifier ensures this doesn't block waiting for a response
        NSLog(@"GNUStepMenuActionHandler: Calling activateMenuItemAtPath:forWindow: on proxy");
        [(id<GSGNUstepMenuClient>)proxy activateMenuItemAtPath:indexPath forWindow:windowId];
        NSLog(@"GNUStepMenuActionHandler: Call completed, dispatched action for menu item '%@'", menuItemTitle);
    }
    @catch (NSException *exception) {
        NSLog(@"GNUStepMenuActionHandler: Exception activating menu item '%@': %@ - %@", menuItemTitle, [exception name], [exception reason]);
    }
}

@end
