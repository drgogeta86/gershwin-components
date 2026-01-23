/*
 * CodeTextBlock.m
 *
 * NSTextBlock subclass that draws a rounded background for code blocks.
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "CodeTextBlock.h"
#import <AppKit/AppKit.h>

@interface CodeTextBlock ()
{
  CGFloat _cornerRadius;
}
@end

@implementation CodeTextBlock

- (id)init
{
  self = [super init];
  if (self)
    {
      _cornerRadius = 6.0;
      [self setBackgroundColor:[NSColor colorWithCalibratedWhite:0.90 alpha:1.0]];
      [self setBorderColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
      /* Provide a small default padding */
      [self setWidth:8.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];
    }
  return self;
}

- (void) setCornerRadius: (CGFloat)r
{
  _cornerRadius = r;
}

- (CGFloat) cornerRadius
{
  return _cornerRadius;
}

- (void) drawBackgroundWithFrame: (NSRect)rect
                          inView: (NSView *)view
                  characterRange: (NSRange)range
                   layoutManager: (NSLayoutManager *)lm
{
  NSRect drawRect = rect;
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:drawRect xRadius:_cornerRadius yRadius:_cornerRadius];
  NSColor *bg = [self backgroundColor];
  if (bg)
    {
      [bg setFill];
      [path fill];
    }
  NSColor *border = [self borderColorForEdge:NSMinXEdge];
  if (border)
    {
      [border setStroke];
      [path stroke];
    }
}

@end
