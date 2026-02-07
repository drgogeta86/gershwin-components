#import <Foundation/Foundation.h>

@interface DesktopFileParser : NSObject
{
  NSMutableDictionary *entries;
}

- (id)initWithFile:(NSString *)path;
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (BOOL)parseFile:(NSString *)path;

@end
