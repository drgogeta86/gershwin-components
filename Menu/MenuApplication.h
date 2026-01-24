/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class MenuController;

@interface MenuApplication : NSApplication <NSApplicationDelegate>
{
}

@property (nonatomic, strong) MenuController *controller;

+ (MenuApplication *)sharedApplication;
- (void)sendEvent:(NSEvent *)event;
- (void)checkForExistingMenuApplicationAsync;

// Expose global controller accessor for other modules to trigger handler directly (testing / fallback)
MenuController *MenuControllerGlobal(void);

@end
