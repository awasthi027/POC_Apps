//
//  AsyncCPlusClass.hpp
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 10/06/25.
//
#include <functional>
#include <iostream>
#include <string>

class AsyncCPlusClass {
public:
    void setCallback(std::function<void(int)> cb);
    void asyncAdd(int a, int b);
    // This method simulates an asynchronous operation
    void addCallback(std::function<void(int)> cb);
    void triggerAll(int value);
    // call back with two parameters
    void setSuccessCallback(std::function<void(int, const std::string&)> cb);
    void asyncOperation(int code);

private:
    std::function<void(int)> callback_;
    std::vector<std::function<void(int)>> callbacks_;
    std::function<void(int, const std::string&)> successCallback_;
};
