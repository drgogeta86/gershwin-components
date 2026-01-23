/*
 * MarkdownProducer.h
 *
 * Writes out a NSAttributedString as Markdown
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _GNUstep_H_MarkdownProducer
#define _GNUstep_H_MarkdownProducer

#include <GNUstepGUI/GSTextConverter.h>

@class NSAttributedString;
@class NSMutableString;
@class NSDictionary;
@class NSFont;
@class NSParagraphStyle;

/**
 * MarkdownProducer converts NSAttributedString objects into Markdown format.
 *
 * This class implements the GSTextProducer protocol to provide seamless
 * conversion from rich text to Markdown. It analyzes text attributes and
 * generates appropriate Markdown syntax for formatting, headings, lists,
 * links, and other supported elements.
 *
 * The producer maintains state about the current text run to optimize
 * output and ensure proper nesting of Markdown syntax elements.
 */
@interface MarkdownProducer : NSObject <GSTextProducer>
{
  @private
  NSAttributedString *_text;
  NSMutableString *_output;
  NSDictionary *_documentAttributes;
  
  /* State tracking for current text run */
  NSFont *_currentFont;
  NSParagraphStyle *_currentParagraphStyle;
  NSDictionary *_currentAttributes;
  
  /* Flags for tracking nested formatting */
  BOOL _inBold;
  BOOL _inItalic;
  BOOL _inCode;
  BOOL _inList;
  BOOL _inBlockquote;
  
  /* Current list state */
  NSUInteger _listLevel;
  BOOL _isOrderedList;
  NSUInteger _listItemNumber;
  
  /* Current paragraph state */
  NSUInteger _headingLevel;
  BOOL _isFirstParagraph;
}

/**
 * Produces Markdown data from an attributed string.
 *
 * @param aText The attributed string to convert to Markdown
 * @param dict Document attributes (currently unused, reserved for future use)
 * @param error Output parameter for error information (may be NULL)
 * @return NSData containing UTF-8 encoded Markdown text, or nil on error
 */
+ (NSData *)produceDataFrom:(NSAttributedString *)aText
         documentAttributes:(NSDictionary *)dict
                      error:(NSError **)error;

@end

#endif /* _GNUstep_H_MarkdownProducer */
