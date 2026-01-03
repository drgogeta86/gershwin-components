/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "NetworkBrowser.h"

int main(int argc, char *argv[])
{
  CREATE_AUTORELEASE_POOL(pool);
  NSApplication *app = [NSApplication sharedApplication];
  NetworkBrowser *browser = [[NetworkBrowser alloc] init];
  
  [app setDelegate: browser];
  [app run];
  
  RELEASE(browser);
  RELEASE(pool);
  return 0;
}
