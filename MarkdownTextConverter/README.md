# Markdown Text Converter

A GNUstep text converter component for rendering and parsing Markdown documents as NSAttributedString objects.

## Overview

MarkdownTextConverter provides bidirectional conversion between Markdown text and NSAttributedString, following the same architecture pattern as GNUstep's RTF text converters. This allows Markdown documents to be seamlessly integrated into GNUstep applications with rich text rendering support.

## Architecture

The component follows GNUstep's GSTextConverter protocol architecture:

- **MarkdownProducer**: Implements `GSTextProducer` protocol to convert NSAttributedString to Markdown format
- **MarkdownConsumer**: Implements `GSTextConsumer` protocol to parse Markdown text into NSAttributedString

Both classes integrate with GNUstep's text system through the standard `NSAttributedString` initialization and data production methods.

## Supported Markdown Features

### Basic Formatting
- **Bold**: `**text**` or `__text__`
- **Italic**: `*text*` or `_text_`
- **Strikethrough**: `~~text~~`
- **Code**: `` `code` ``
- **Links**: `[text](url)`

### Block Elements
- Headings: `# H1` through `###### H6`
- Paragraphs with automatic spacing
- Code blocks: ` ```language ` fenced blocks
- Blockquotes: `> quoted text`
- Horizontal rules: `---` or `***`

### Lists
- Unordered lists: `- item` or `* item`
- Ordered lists: `1. item`
- Nested lists with proper indentation

## Usage

### Reading Markdown

```objc
NSData *markdownData = [NSData dataWithContentsOfFile:@"document.md"];
NSDictionary *docAttrs = nil;
NSAttributedString *attrString = 
    [[NSAttributedString alloc] initWithMarkdown:markdownData
                              documentAttributes:&docAttrs];
```

### Writing Markdown

```objc
NSAttributedString *attrString = // ... your attributed string
NSDictionary *docAttrs = @{};
NSData *markdownData = 
    [attrString dataFromRange:NSMakeRange(0, [attrString length])
           documentAttributes:docAttrs
                        error:NULL];
```

## Implementation Details

The parser is implemented entirely in Objective-C without external dependencies, using a state-machine approach for efficient and reliable Markdown parsing. The renderer maps NSAttributedString attributes to appropriate Markdown syntax while preserving text structure.

## Integration with GNUstep

This component registers itself with GNUstep's text conversion system automatically, allowing NSAttributedString to recognize and handle Markdown format through standard APIs:

- `initWithMarkdown:documentAttributes:`
- `initWithMarkdownString:documentAttributes:`
- Data production through document attributes

## Building

```bash
cd MarkdownTextConverter
make
make install
```

## License

Copyright (c) 2026 Simon Peter

SPDX-License-Identifier: BSD-2-Clause

This component is released under the BSD 2-Clause license, maintaining compatibility with GNUstep's licensing.

## See Also

- GNUstep RTF text converters (libs-gui/TextConverters/RTF/)
- NSAttributedString documentation
- GSTextConverter protocol documentation
