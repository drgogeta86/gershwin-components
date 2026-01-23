/*
 * MarkdownConsumer.h
 *
 * Parses Markdown text into NSAttributedString
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

#ifndef _GNUstep_H_MarkdownConsumer
#define _GNUstep_H_MarkdownConsumer

#include <GNUstepGUI/GSTextConverter.h>

@class NSMutableAttributedString;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSFont;
@class NSParagraphStyle;

/**
 * MarkdownConsumer parses Markdown text into NSAttributedString objects.
 *
 * This class implements the GSTextConsumer protocol to provide parsing
 * of Markdown documents into rich text. It supports standard Markdown
 * syntax including headings, emphasis, lists, links, code blocks, and more.
 *
 * The parser uses a state-machine approach to process Markdown line-by-line,
 * maintaining context about block-level elements (lists, quotes, code blocks)
 * while handling inline formatting (bold, italic, code, links).
 */
@interface MarkdownConsumer : NSObject <GSTextConsumer>
{
  @private
  NSMutableAttributedString *_result;
  NSMutableDictionary *_documentAttributes;
  Class _attributedStringClass;
  
  /* Font cache for different styles */
  NSFont *_bodyFont;
  NSFont *_boldFont;
  NSFont *_italicFont;
  NSFont *_boldItalicFont;
  NSFont *_codeFont;
  NSMutableArray *_headingFonts; /* Array of fonts for H1-H6 */
  
  /* Paragraph styles cache */
  NSParagraphStyle *_normalParagraphStyle;
  NSParagraphStyle *_blockquoteParagraphStyle;
  NSMutableArray *_listParagraphStyles; /* Styles for different list levels */
  
  /* Parser state */
  BOOL _inCodeBlock;
  BOOL _inBlockquote;
  BOOL _inList;
  NSUInteger _listLevel;
  BOOL _isOrderedList;
  NSString *_codeBlockLanguage;
  NSMutableString *_codeBlockContent;
  
  /* Current line state */
  NSUInteger _currentIndentLevel;
  NSString *_currentLine;
}

/**
 * Parses Markdown data into an attributed string.
 *
 * @param aData Raw data containing UTF-8 encoded Markdown text
 * @param options Parsing options (reserved for future use)
 * @param dict Output parameter for document attributes (may be NULL)
 * @param error Output parameter for error information (may be NULL)
 * @param class The NSAttributedString class or subclass to instantiate
 * @return A new NSAttributedString instance containing the parsed result
 */
+ (NSAttributedString *)parseData:(NSData *)aData
                          options:(NSDictionary *)options
               documentAttributes:(NSDictionary **)dict
                            error:(NSError **)error
                            class:(Class)class;

@end

#endif /* _GNUstep_H_MarkdownConsumer */
