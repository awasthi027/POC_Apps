//
//  ObjCAsyncCommunication.mm
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 10/06/25.
//

#import "CPlusPlusAsyncCommunication.h"
#include "AsyncCPlusClass.hpp"
#include <functional>
#include <iostream>


@implementation CPlusPlusAsyncCommunication

- (void)addNumber:(int)firstNumber
                           second:(int) secondNumber
                  completeHandler:(CompleteRequest)completion {
    AsyncCPlusClass obj;
    obj.setCallback([&completion](int value) {
            std::cout << "Callback called with value: " << value << std::endl;
            completion(value, nil);
        });
    obj.asyncAdd(firstNumber, secondNumber);
}

- (void)multipleCallBack:(int)value
         completeHandler:(CompleteRequest)completion  {
    AsyncCPlusClass obj;
    obj.addCallback([&completion](int v) {
        std::cout << "First: " << v << std::endl;
        completion(v, nil);
    });
    obj.addCallback([&completion](int v){
        std::cout << "Second: " << v << std::endl;
        completion(v, nil);
    });
    obj.triggerAll(value);
}

- (void)setupCallbacks:(int) code
                  completeHandler:(CompleteRequest)completion {
    AsyncCPlusClass obj;
    obj.setSuccessCallback([&completion](int code, const std::string& msg) {
        NSString *nsMsg = [NSString stringWithUTF8String:msg.c_str()];
        if ([nsMsg  isEqual: @""]) {
            completion(code, nil);
        }else {
            completion(0, nsMsg);
        }
    });
    obj.asyncOperation(code);
}

@end
