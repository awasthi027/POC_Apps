//
//  HttpRequestApple.cpp
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 17/04/25.
//

#include "HttpRequest.hpp"
#import <Foundation/Foundation.h>

void HttpRequest::get(const std::string& url, const Callback& callback) {
    NSString *nsUrl = [NSString stringWithUTF8String:url.c_str()];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:nsUrl]
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        int statusCode = (int)[(NSHTTPURLResponse *)response statusCode];
        std::string responseStr;
        std::string errorStr;

        if (error) {
            errorStr = error.localizedDescription.UTF8String;
        } else if (data) {
            responseStr = std::string((const char *)data.bytes, data.length);
        }

        callback(responseStr, statusCode, errorStr);
    }];
    [task resume];
}
