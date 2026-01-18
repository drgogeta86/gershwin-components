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
@end
