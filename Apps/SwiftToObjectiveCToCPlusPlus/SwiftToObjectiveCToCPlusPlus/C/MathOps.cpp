//
//  MathOps.m
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 15/04/25.
//
#include "MathOps.h"

int addNumber(int a, int b) {
    return a + b;
}

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void start_async_work(CAsyncCallback callback, void* context) {
    const char* result = "Hello from C async world!";
    callback(result, strlen(result), 0, context);
}



void perform_async_operation(
    const void* data,
    size_t length,
    CompletionCallback callback,
    void *context) {

    // Call back with result
    callback(data, length, 0, context); // Error code 0 = success
    // Parent process continues
}

void sampleCall(
    const char *input,
    SimpleCallBack callback,
    void *context) {
    callback(input,
             0,
             context);
}
