/*
 * AppController.h
 *
 * MarkdownReader Application Delegate
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef _AppController_H_
#define _AppController_H_

#import <AppKit/NSApplication.h>
#import <Foundation/NSObject.h>

@class NSWindow;
@class NSTextView;

@interface AppController : NSObject
{
}

- (void) applicationWillFinishLaunching: (NSNotification *)notifier;
- (void) applicationDidFinishLaunching: (NSNotification *)notifier;
- (BOOL) application: (NSApplication *)app openFile: (NSString *)filename;

- (void) openDocument: (id)sender;
- (void) showAboutPanel: (id)sender;

@end

#endif
