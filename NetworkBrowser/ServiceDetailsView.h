/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SERVICEDETAILSVIEW_H
#define SERVICEDETAILSVIEW_H

#import <AppKit/NSView.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSScrollView.h>
#import <Foundation/NSNetServices.h>

@interface ServiceDetailsView : NSView
{
  NSScrollView *scrollView;
  NSTextView *textView;
  NSNetService *currentService;
}

- (id)initWithFrame:(NSRect)frame;
- (void)displayService:(NSNetService *)service;
- (void)clear;

@end

#endif // SERVICEDETAILSVIEW_H
