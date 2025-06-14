//
//  MathOps.h
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 15/04/25.
//

int addNumber(int a, int b);

#ifndef async_worker_h
#define async_worker_h

#include <stddef.h>

typedef void (*CAsyncCallback)(const void* data, size_t length, int error, void* context);

void start_async_work(CAsyncCallback callback, void* context);


// Define callback type
typedef void (*CompletionCallback)(const void* data,
                                   size_t length,
                                   int errorCode,
                                   void *context);

// Function with multiple parameters and callback
void perform_async_operation(
    const void* data,
    size_t length,
    CompletionCallback callback,
    void *context
);

// Define callback type
typedef void (*SimpleCallBack)(const char *result, int errorCode, void *context);

// Function with multiple parameters and callback
void sampleCall(
    const char *input,
    SimpleCallBack callback,
    void *context
);

#endif /* async_worker_h */

