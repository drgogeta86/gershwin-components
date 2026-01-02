/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import <AppKit/NSApplication.h>
#import <AppKit/NSAlert.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ScreenshotController.h"
#import "ScreenshotCapture.h"

int main(int argc, const char *argv[]) {
   // Always run as GUI app (even with command-line args)
   // Set flag in controller if command-line args are present
   BOOL hasCommandLineArgs = (argc > 1);
   
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
   
   // Create the application
   [NSApplication sharedApplication];
   
   // Create and set the controller as the delegate
   ScreenshotController *controller = [[ScreenshotController alloc] init];
   
   // Initialize X11 directly here before showing UI
   if (![ScreenshotCapture initializeX11]) {
       NSAlert *alert = [[NSAlert alloc] init];
       [alert setMessageText:@"Screenshot Error"];
       [alert setInformativeText:@"Failed to initialize screenshot system. Make sure X11 is running."];
       [alert setAlertStyle:NSCriticalAlertStyle];
       [alert runModal];
       [alert release];
       [controller release];
       [pool release];
       return 1;
   }
   
   [[NSApplication sharedApplication] setDelegate:controller];
   [controller createUI];
   
   // If command-line args provided, hide window and process them
   if (hasCommandLineArgs) {
       [controller handleCommandLineArguments];
   }
   
   [pool release];
   
   // Run the application
   [[NSApplication sharedApplication] run];
   return 0;
}