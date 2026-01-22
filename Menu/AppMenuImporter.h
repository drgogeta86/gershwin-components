/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class GNUDBusConnection;

/**
 * AppMenuImporter
 * 
 * Unified menu importer with async GTK menu support.
 * Handles Canonical AppMenu and GTK org.gtk.Menus with proper cancellation.
 */
@interface AppMenuImporter : NSObject

@property (nonatomic, strong) GNUDBusConnection *dbusConnection;
@property (nonatomic, assign) dispatch_queue_t menuQueue;

+ (instancetype)sharedImporter;

/**
 * Called when active window changes.
 * Cancels previous import and starts new one with 100ms delay.
 */
- (void)activeWindowChanged:(unsigned long)windowId;

/**
 * Import menu for specific window (async).
 */
- (void)importMenuForWindow:(unsigned long)windowId
                 completion:(void(^)(NSMenu *menu, NSError *error))completion;

/**
 * Check if window is a GNUstep window (uses GNUstep IPC instead).
 */
- (BOOL)isGNUstepWindow:(unsigned long)windowId;

/**
 * Cancel any pending imports.
 */
- (void)cancelPendingImports;

/**
 * Cleanup resources.
 */
- (void)cleanup;

@end
