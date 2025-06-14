//
//  HttpRequestApple..hpp
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 17/04/25.
//

#pragma once
#include <string>
#include <functional>

class HttpRequest {
public:
    using Callback = std::function<void(const std::string& response, int statusCode, const std::string& error)>;
    static void get(const std::string& url, const Callback& callback);
};
