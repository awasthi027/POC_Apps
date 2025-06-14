//
//  AACPlusPlusWrapper.m
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/04/25.
//

#import <Foundation/Foundation.h>

typedef void (^FetchCompletion)(NSString *result, NSError *error);

@interface SimpleCPlusPlusWrapper: NSObject

- (NSString *)combindMyName:(NSString *) firstName
                   lastName: (NSString *) lastName;
- (int)addNumber:( int) a
               b: (int) b;
- (void)makeGetRequest:(NSString *)urlStr
       completeHandler:(FetchCompletion)completion;
@end
