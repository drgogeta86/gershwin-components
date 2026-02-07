/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */
 
#import "DesktopFileParser.h"
#import "GWUtils.h"

@implementation DesktopFileParser

- (id)init
{
  self = [super init];
  if (self)
    {
      entries = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (id)initWithFile:(NSString *)path
{
  self = [self init];
  if (self && ![self parseFile:path])
    {
      [self release];
      return nil;
    }
  return self;
}

- (BOOL)parseFile:(NSString *)path
{
  NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile:path 
                                                  encoding:NSUTF8StringEncoding 
                                                     error:&error];
  if (!content)
    {
      NSString *msg = [NSString stringWithFormat:@"Error reading file: %@", [error localizedDescription]];
      [GWUtils showErrorAlertWithTitle:@"Error reading desktop file" message:msg];
      return NO;
    }

  NSArray *lines = [content componentsSeparatedByString:@"\n"];
  NSString *currentSection = nil;

  for (NSString *line in lines)
    {
      // Skip empty lines and comments
      NSString *trimmed = [line stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]];
      if ([trimmed length] == 0 || [trimmed hasPrefix:@"#"])
        continue;

      // Handle sections
      if ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"])
        {
          currentSection = [trimmed substringWithRange:NSMakeRange(1, [trimmed length] - 2)];
          continue;
        }

      // Skip lines that are not in Desktop Entry section
      if (![currentSection isEqualToString:@"Desktop Entry"])
        continue;

      // Parse key=value pairs
      NSArray *parts = [trimmed componentsSeparatedByString:@"="];
      if ([parts count] >= 2)
        {
          NSString *key = [[parts objectAtIndex:0] stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
          NSString *value = [[parts objectAtIndex:1] stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
          
          // Handle values with '=' in them
          if ([parts count] > 2)
            {
              NSMutableArray *valueParts = [NSMutableArray arrayWithArray:
                                            [parts subarrayWithRange:NSMakeRange(1, [parts count] - 1)]];
              value = [valueParts componentsJoinedByString:@"="];
              value = [value stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
            }

          [entries setObject:value forKey:key];
        }
    }

  return YES;
}

- (NSString *)stringForKey:(NSString *)key
{
  return [entries objectForKey:key];
}

- (NSArray *)arrayForKey:(NSString *)key
{
  NSString *value = [entries objectForKey:key];
  if (!value)
    return nil;
  
  // Handle semicolon-separated values (freedesktop standard)
  return [value componentsSeparatedByString:@";"];
}

- (void)dealloc
{
  [entries release];
  [super dealloc];
}

@end
