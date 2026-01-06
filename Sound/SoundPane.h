/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Sound Preference Pane
 */

#import <PreferencePanes/PreferencePanes.h>

@class SoundController;

@interface SoundPane : NSPreferencePane
{
    SoundController *controller;
    NSTimer *refreshTimer;
}

@end
