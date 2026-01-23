/*
 * Copyright 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <AppKit/AppKit.h>

@interface BuildApplication : NSApplication <NSApplicationDelegate>
{
    NSString *makefilePath;
    NSArray *extraArgs;
}

@property (retain) NSString *makefilePath;
@property (retain) NSArray *extraArgs;

@end