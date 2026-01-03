/*
 * NSICNSImageRep.h
 * ICNS Image Representation for GNUstep
 *
 * Provides support for reading ICNS icon files throughout the system.
 */

#import <AppKit/NSImageRep.h>

@interface NSICNSImageRep : NSImageRep
{
    NSData *_icnsData;
    NSMutableArray *_representations;
}

+ (void)load;
+ (NSArray *)imageUnfilteredFileTypes;
+ (NSArray *)imageUnfilteredPasteboardTypes;
+ (BOOL)canInitWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;

@end
