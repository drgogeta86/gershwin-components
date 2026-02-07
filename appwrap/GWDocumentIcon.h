#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface GWDocumentIcon : NSObject

+ (NSString *)createDocumentIconInResources:(NSString *)resourcesPath
                                    appName:(NSString *)appName
                           appIconFilename:(NSString *)appIconFilename
                                    mimeType:(NSString *)mimeType
                                    typeName:(NSString *)typeName
                                        size:(int)size;

@end
