/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>

@protocol GSGNUstepMenuServer
- (oneway void)updateMenuForWindow:(NSNumber *)windowId
                          menuData:(NSDictionary *)menuData
                        clientName:(NSString *)clientName;
- (oneway void)unregisterWindow:(NSNumber *)windowId
                       clientName:(NSString *)clientName;
@end

@protocol GSGNUstepMenuClient
- (oneway void)activateMenuItemAtPath:(NSArray *)indexPath
                            forWindow:(NSNumber *)windowId;

// Request the client to push its current menu for the given X11 window ID.
// This allows the server to import menus from already-mapped GNUstep windows
// (for example the Desktop) by asking the client to send its menu via
// updateMenuForWindow:menuData:clientName:.
- (oneway void)requestMenuUpdateForWindow:(NSNumber *)windowId;
@end
