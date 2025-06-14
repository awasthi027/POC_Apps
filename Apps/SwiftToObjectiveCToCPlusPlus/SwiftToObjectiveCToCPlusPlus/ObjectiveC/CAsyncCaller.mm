//
//  CAsyncCaller.m
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 12/06/25.
//

#import <Foundation/Foundation.h>
#import "ObjCppUtils.h"
#import "CAsyncCaller.h"
#import "MathOps.h"


static void delegateCallBack(const void* data,
                           size_t length,
                           int errorCode,
                           void *context) {
    // Convert context back to Objective-C object
    __weak CAsyncCaller* caller = (__bridge CAsyncCaller*)context;
    CBuffer buffer = {data,length};
    NSData* resultData = nsDatFromCData(buffer);
    NSError* resultError = nil;

    if (errorCode != 0) {
        resultError = [NSError errorWithDomain:@"CAsyncErrorDomain"
                                      code:errorCode
                                  userInfo:nil];
    }
    // Dispatch back to main queue to call delegate
    dispatch_async(dispatch_get_main_queue(), ^{
        [caller.delegate didReceiveData:resultData error:resultError];
    });
}

static void blockCallBack(const char *result,
                            int errorCode,
                            void *context) {
    // Unpack the context (our completion block)
    AsyncCompletion completion = (__bridge AsyncCompletion)context;

    // Convert to Objective-C types
    NSString *nsResult = nsStringFromCString(result);
    NSError *error = nil;

    if (errorCode != 0) {
        NSString *errorDomain = @"com.example.asyncoperations";
        NSString *errorDescription = @"Unknown error";

        switch (errorCode) {
            case 1: errorDescription = @"Invalid input"; break;
            case 2: errorDescription = @"Memory allocation failed"; break;
        }

        error = [NSError errorWithDomain:errorDomain
                                   code:errorCode
                               userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
    }

    // Ensure we execute on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nsResult, error);
    });

    // Release the block (since we bridged it as retained)
    CFBridgingRelease(context);
}

// C callback function that bridges to Objective-C
static void c_callback(const void* data, size_t length, int errorCode, void* context) {
    delegateCallBack(data, length, errorCode, context);
}

static void completionCallback(const void* data,
                               size_t length,
                               int errorCode,
                               void *context) {
    //delegateCallBack(data, length, errorCode, context);
    CBuffer buffer = {data, length};
    const char *c_input = cStringFromCBuffer(buffer).cString;
    blockCallBack(c_input, errorCode, context);
}
// Static C callback function that bridges to Objective-C block

static void callBack(const char *result, int errorCode, void *context) {
    blockCallBack(result, errorCode, context);
}


@implementation CAsyncCaller

- (void)startAsyncOperation  {
    // Pass self as context (bridge to void*)
    start_async_work(c_callback, (__bridge void*)self);
}

- (void)performAsyncOperationWithInput:(NSData *)input
                            completion:(AsyncCompletion)completion {
    // Retain the completion block to use as context
    void *context = (void *)CFBridgingRetain([completion copy]);

    CBuffer buffer = nsDataToCBuffer(input);
    // Call the C function
    perform_async_operation(buffer.data,
                            [input length],
                            completionCallback,
                            context);
}

- (void)sampleCallBackRequest:(NSString *)inputStr
                   completion:(AsyncCompletion)completion {
    // Retain the completion block to use as context
    void *context = (void *)CFBridgingRetain([completion copy]);

    sampleCall(cStringFromNSString(inputStr).cString,
               callBack,
               context);
}

@end
