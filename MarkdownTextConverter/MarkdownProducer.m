/*
 * MarkdownProducer.m
 *
 * Writes out a NSAttributedString as Markdown
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "MarkdownProducer.h"
#import <Foundation/Foundation.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontManager.h>
#import <AppKit/NSParagraphStyle.h>
#import <AppKit/NSTextAttachment.h>
#import <AppKit/NSColor.h>

@implementation MarkdownProducer

+ (void)initialize
{
  if (self == [MarkdownProducer class])
    {
      /* Register with GNUstep text converter system if needed */
    }
}

+ (NSData *)produceDataFrom:(NSAttributedString *)aText
         documentAttributes:(NSDictionary *)dict
                      error:(NSError **)error
{
  MarkdownProducer *producer;
  NSString *markdown;
  NSData *data;
  
  if (aText == nil || [aText length] == 0)
    {
      return [NSData data];
    }
  
  producer = [[self alloc] init];
  markdown = [producer _produceMarkdownFromAttributedString:aText
                                         documentAttributes:dict];
  RELEASE(producer);
  
  if (markdown == nil)
    {
      if (error != NULL)
        {
          *error = [NSError errorWithDomain:@"MarkdownProducerErrorDomain"
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to produce Markdown"}];
        }
      return nil;
    }
  
  data = [markdown dataUsingEncoding:NSUTF8StringEncoding];
  return data;
}

- (id)init
{
  self = [super init];
  if (self)
    {
      _output = [[NSMutableString alloc] init];
      _inBold = NO;
      _inItalic = NO;
      _inCode = NO;
      _inList = NO;
      _inBlockquote = NO;
      _listLevel = 0;
      _isOrderedList = NO;
      _listItemNumber = 0;
      _headingLevel = 0;
      _isFirstParagraph = YES;
    }
  return self;
}

- (void)dealloc
{
  RELEASE(_output);
  RELEASE(_text);
  RELEASE(_documentAttributes);
  RELEASE(_currentFont);
  RELEASE(_currentParagraphStyle);
  RELEASE(_currentAttributes);
  [super dealloc];
}

- (NSString *)_produceMarkdownFromAttributedString:(NSAttributedString *)text
                                documentAttributes:(NSDictionary *)docAttrs
{
  NSUInteger length = [text length];
  NSRange effectiveRange;
  NSUInteger index = 0;
  
  _text = RETAIN(text);
  _documentAttributes = RETAIN(docAttrs);
  
  while (index < length)
    {
      NSDictionary *attributes = [text attributesAtIndex:index
                                           effectiveRange:&effectiveRange];
      NSString *substring = [[text string] substringWithRange:effectiveRange];
      
      [self _appendString:substring withAttributes:attributes];
      
      index = NSMaxRange(effectiveRange);
    }
  
  /* Close any remaining formatting */
  [self _closeAllFormatting];
  
  return [[_output copy] autorelease];
}

- (void)_appendString:(NSString *)string withAttributes:(NSDictionary *)attributes
{
  NSFont *font = [attributes objectForKey:NSFontAttributeName];
  NSURL *link = [attributes objectForKey:NSLinkAttributeName];
  NSNumber *strikethrough = [attributes objectForKey:NSStrikethroughStyleAttributeName];
  
  /* Check for heading level based on font size */
  NSUInteger headingLevel = [self _headingLevelForFont:font];
  
  /* Handle paragraph breaks */
  if ([string rangeOfString:@"\n"].location != NSNotFound)
    {
      NSArray *lines = [string componentsSeparatedByString:@"\n"];
      for (NSUInteger i = 0; i < [lines count]; i++)
        {
          NSString *line = [lines objectAtIndex:i];
          
          if (i > 0)
            {
              [self _closeAllFormatting];
              [_output appendString:@"\n"];
              if (headingLevel > 0 || ![line isEqualToString:@""])
                {
                  [_output appendString:@"\n"];
                }
              _isFirstParagraph = NO;
            }
          
          if ([line length] > 0)
            {
              [self _appendLine:line
                    withAttributes:attributes
                          font:font
                  headingLevel:headingLevel
                          link:link
                 strikethrough:strikethrough];
            }
        }
    }
  else
    {
      [self _appendLine:string
            withAttributes:attributes
                      font:font
              headingLevel:headingLevel
                      link:link
             strikethrough:strikethrough];
    }
}

- (void)_appendLine:(NSString *)line
     withAttributes:(NSDictionary *)attributes
               font:(NSFont *)font
       headingLevel:(NSUInteger)headingLevel
               link:(NSURL *)link
      strikethrough:(NSNumber *)strikethrough
{
  BOOL isBold = [self _isBoldFont:font];
  BOOL isItalic = [self _isItalicFont:font];
  BOOL isCode = [self _isCodeFont:font];
  
  /* Handle headings */
  if (headingLevel > 0 && _headingLevel != headingLevel)
    {
      _headingLevel = headingLevel;
      for (NSUInteger i = 0; i < headingLevel; i++)
        {
          [_output appendString:@"#"];
        }
      [_output appendString:@" "];
    }
  
  /* Handle inline code */
  if (isCode && !_inCode)
    {
      [_output appendString:@"`"];
      _inCode = YES;
    }
  else if (!isCode && _inCode)
    {
      [_output appendString:@"`"];
      _inCode = NO;
    }
  
  /* Handle strikethrough */
  if (strikethrough != nil && [strikethrough intValue] > 0)
    {
      [_output appendString:@"~~"];
    }
  
  /* Handle bold */
  if (isBold && !_inBold && !isCode)
    {
      [_output appendString:@"**"];
      _inBold = YES;
    }
  else if (!isBold && _inBold)
    {
      [_output appendString:@"**"];
      _inBold = NO;
    }
  
  /* Handle italic */
  if (isItalic && !_inItalic && !isCode)
    {
      [_output appendString:@"*"];
      _inItalic = YES;
    }
  else if (!isItalic && _inItalic)
    {
      [_output appendString:@"*"];
      _inItalic = NO;
    }
  
  /* Handle links */
  if (link != nil)
    {
      [_output appendFormat:@"[%@](%@)", line, [link absoluteString]];
    }
  else
    {
      /* Escape special Markdown characters in normal text */
      NSString *escaped = [self _escapeMarkdownCharacters:line inCode:isCode];
      [_output appendString:escaped];
    }
  
  /* Close strikethrough */
  if (strikethrough != nil && [strikethrough intValue] > 0)
    {
      [_output appendString:@"~~"];
    }
}

- (void)_closeAllFormatting
{
  if (_inCode)
    {
      [_output appendString:@"`"];
      _inCode = NO;
    }
  if (_inBold)
    {
      [_output appendString:@"**"];
      _inBold = NO;
    }
  if (_inItalic)
    {
      [_output appendString:@"*"];
      _inItalic = NO;
    }
  _headingLevel = 0;
}

- (NSUInteger)_headingLevelForFont:(NSFont *)font
{
  if (font == nil)
    return 0;
  
  CGFloat fontSize = [font pointSize];
  CGFloat systemFontSize = [NSFont systemFontSize];
  
  /* Map font sizes to heading levels */
  if (fontSize >= systemFontSize * 2.0)
    return 1; /* H1 */
  else if (fontSize >= systemFontSize * 1.7)
    return 2; /* H2 */
  else if (fontSize >= systemFontSize * 1.5)
    return 3; /* H3 */
  else if (fontSize >= systemFontSize * 1.3)
    return 4; /* H4 */
  else if (fontSize >= systemFontSize * 1.15)
    return 5; /* H5 */
  else if (fontSize >= systemFontSize * 1.05)
    return 6; /* H6 */
  
  return 0;
}

- (BOOL)_isBoldFont:(NSFont *)font
{
  if (font == nil)
    return NO;
  
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFontTraitMask traits = [fontManager traitsOfFont:font];
  
  return (traits & NSBoldFontMask) != 0;
}

- (BOOL)_isItalicFont:(NSFont *)font
{
  if (font == nil)
    return NO;
  
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFontTraitMask traits = [fontManager traitsOfFont:font];
  
  return (traits & NSItalicFontMask) != 0;
}

- (BOOL)_isCodeFont:(NSFont *)font
{
  if (font == nil)
    return NO;
  
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFontTraitMask traits = [fontManager traitsOfFont:font];
  
  /* Monospace fonts are typically used for code */
  return (traits & NSFixedPitchFontMask) != 0;
}

- (NSString *)_escapeMarkdownCharacters:(NSString *)string inCode:(BOOL)inCode
{
  if (inCode)
    {
      /* In code spans, only backticks need escaping */
      return [string stringByReplacingOccurrencesOfString:@"`"
                                               withString:@"\\`"];
    }
  
  /* Escape Markdown special characters */
  NSMutableString *escaped = [NSMutableString stringWithString:string];
  
  NSArray *specialChars = @[@"\\", @"*", @"_", @"[", @"]", @"(", @")",
                            @"#", @"+", @"-", @".", @"!", @"|", @"~"];
  
  for (NSString *ch in specialChars)
    {
      NSString *escapedChar = [NSString stringWithFormat:@"\\%@", ch];
      [escaped replaceOccurrencesOfString:ch
                               withString:escapedChar
                                  options:0
                                    range:NSMakeRange(0, [escaped length])];
    }
  
  return escaped;
}

@end
