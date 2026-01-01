/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <PreferencePanes/PreferencePanes.h>

@class PrintersController;

@interface PrintersPane : NSPreferencePane
{
    PrintersController *controller;
    NSTimer *refreshTimer;
}

@end
