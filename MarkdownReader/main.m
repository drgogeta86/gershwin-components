#import <Foundation/Foundation.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSMenu.h>
#import "AppController.h"

int main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [NSApplication sharedApplication];
  
  AppController *controller = [[AppController alloc] init];
  [NSApp setDelegate: controller];
  
  [NSApp run];
  
  [pool release];
  return 0;
}
