//
//  WKWebView+Swizzle.m
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//


#if __has_include("CoreHelpers-Swift.h")
#import "CoreHelpers-Swift.h"
#elif __has_include(<CoreHelpers/CoreHelpers-Swift.h>)
#import <CoreHelpers/CoreHelpers-Swift.h>
#else
@import CoreHelpers;
#endif


#if TARGET_OS_IOS

@implementation WKWebView (Swizzle)

+ (void) load {
    [self swizzleRequiredMethods];
}

@end

#endif
