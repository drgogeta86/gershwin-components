/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import "MenuProtocolManager.h"
#import "GNUStepMenuIPC.h"

@class AppMenuWidget;

@interface GNUStepMenuImporter : NSObject <MenuProtocolHandler, GSGNUstepMenuServer>

@property (nonatomic, weak) AppMenuWidget *appMenuWidget;

@end
