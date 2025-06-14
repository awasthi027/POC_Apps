//
//  AsyncCPlusClass.cpp
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 10/06/25.
//


#include "AsyncCPlusClass.hpp"

#include <functional>
#include <iostream>

void AsyncCPlusClass::setCallback(std::function<void(int)> cb) {
    callback_ = cb;
}

void AsyncCPlusClass:: asyncAdd(int a, int b) {
    if (callback_) {
        callback_(a + b); // Example value
    }

}

void AsyncCPlusClass::addCallback(std::function<void(int)> cb) {
    callbacks_.push_back(cb);
}

void AsyncCPlusClass::triggerAll(int value) {
      for (auto& cb : callbacks_) {
          if (cb) cb(value);
      }
  }

void AsyncCPlusClass::setSuccessCallback(std::function<void(int, const std::string&)> cb) {
    // Store the callback for later use
    successCallback_ = cb;
}

void AsyncCPlusClass::asyncOperation(int code) {
    if (successCallback_) {
        if (code == 0) {
            successCallback_(code, "Unexpected inputs parameters");
        }else {
            successCallback_(code, "");
        }
    }
}
