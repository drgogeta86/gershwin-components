#import <AppKit/NSApplication.h>
#import <AppKit/NSAlert.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ScreenshotController.h"
#import "ScreenshotCapture.h"

int main(int argc, const char *argv[]) {
   // Check if we have command-line arguments that indicate CLI mode
   // (more than just the program name, and not just opening a file)
   BOOL isCommandLineMode = NO;
   
   for (int i = 1; i < argc; i++) {
       const char *arg = argv[i];
       // Check for option flags
       if (arg[0] == '-' || (i == 1 && argc > 1)) {
           isCommandLineMode = YES;
           break;
       }
   }
   
   if (isCommandLineMode && argc > 1) {
       // Create autorelease pool for command-line mode
       NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
       
       // Create controller and handle command line directly
       ScreenshotController *controller = [[ScreenshotController alloc] init];
       [controller handleCommandLineArguments];
       [controller release];
       
       [pool release];
       return 0;
   }
   
   // GUI mode - set up application and controller
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
   
   [pool release];
   
   // Run the application - window will be shown by applicationDidFinishLaunching or we can show it here
   [[NSApplication sharedApplication] run];
   return 0;
   return 0;
}