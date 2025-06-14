//
//  AACPlusPlusWrapper.m
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/04/25.
//

#import <Foundation/Foundation.h>
#import "SimpleCPlusPlusWrapper.h"
#include "MathOperation.hpp"
#include "StringOperation.hpp"
#include "MathOps.h"
#include "HttpRequest.hpp"


@implementation SimpleCPlusPlusWrapper {
    StringOperation *strOperation; // C++ instance as an ivar
}

- (instancetype)init {
    self = [super init];
    if (self) {
        strOperation = new StringOperation(); // Create C++ object
    }
    return self;
}

- (void)dealloc {
    delete strOperation; // Clean up C++ object
}

- (NSString *)combindMyName:(NSString *) firstName
                   lastName: (NSString *) lastName {
    NSMutableString *combindString = [[NSMutableString alloc] initWithString: firstName];
    [combindString appendString: [NSString stringWithFormat:@" %@", lastName]];
    std::string cppName = [combindString UTF8String];
    strOperation->greet(cppName);
    return combindString;
}

- (int)addNumber:( int) a b: (int) b {
    int result = MathOperation::addNumbers( a, b);
    NSLog(@"Static Method Sum: %d",result);
    return  addNumber(a, b);
}

- (void)makeGetRequest:(NSString *)urlStr
       completeHandler:(FetchCompletion)completion {
    [[maybe_unused]] volatile int keepAlive = 0;
    std::string url = [urlStr UTF8String];
    HttpRequest::get(url, [&] (const std::string& response, int code, const std::string& error) {
        if (!error.empty()) {
            NSString *responseString = [NSString stringWithUTF8String:error.c_str()];
            NSLog(@"Error: %@",responseString);
            completion(responseString, nil);
            //std::cerr << "Error: " << error << std::endl;
        } else {
            NSString *responseString = [NSString stringWithUTF8String:response.c_str()];
            NSLog(@"Response: %@",responseString);
            completion(responseString, nil);
            //  std::cout << "Status: " << code << "\nResponse: " << response << std::endl;
        }
        keepAlive = 1;
    });
    // Keep the program alive long enough for the async request

    while (keepAlive == 0) {}
}


@end
