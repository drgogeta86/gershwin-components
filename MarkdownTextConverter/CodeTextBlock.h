/*
 * CodeTextBlock.h
 *
 * NSTextBlock subclass that draws a rounded background for code blocks.
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef _GNUstep_H_CodeTextBlock
#define _GNUstep_H_CodeTextBlock

#import <AppKit/NSTextTable.h>

@interface CodeTextBlock : NSTextBlock

- (void) setCornerRadius: (CGFloat)r;
- (CGFloat) cornerRadius;

@end

#endif
