//
//  ObjCppUtils.m
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/06/25.
//

#import "ObjCppUtils.h"

CBuffer nsDataToCBuffer(NSData *input) {
    void *copiedData = malloc([input length]);
    memcpy(copiedData, [input bytes], [input length]);
    CBuffer buffer = {copiedData, [input length]};
    return buffer;
}

NSData* cBufferToNSData(CBuffer buffer) {
    NSData* nsData = nil;
    if (buffer.data && buffer.length > 0) {
        nsData = [NSData dataWithBytes: buffer.data length: buffer.length];
    }
    return nsData;
}

NSString* cBufferToNSString(CBuffer buffer) {
    NSData* data = cBufferToNSData(buffer);
    NSString *string = [[NSString alloc]
                          initWithData: data
                          encoding:NSUTF8StringEncoding];
    return string;
}

CString cStringFromCBuffer(CBuffer buffer) {
    NSData* data = cBufferToNSData(buffer);
    NSString *string = [[NSString alloc]
                          initWithData: data
                          encoding:NSUTF8StringEncoding];
    const char *c_input = [string UTF8String];
    CString cString = { c_input, [string length] };
    return cString;
}

CString cStringFromNSString(NSString *nsStr) {
    const char *c_input = [nsStr UTF8String];
    CString cString = { c_input, [nsStr length] };
    return cString;
}

NSString* nsStringFromCString(const char *result) {
    return [NSString stringWithUTF8String:result];
}

NSData* nsDatFromCData(CBuffer buffer) {
    return [NSData dataWithBytes: buffer.data
                          length: buffer.length];
}

namespace ObjCppUtils {

    std::string nsStringToStdString(NSString *nsString) {
        if (!nsString) return "";
        return [nsString UTF8String] ?: "";
    }

    NSString* stdStringToNSString(const std::string &stdString) {
        return [NSString stringWithUTF8String:stdString.c_str()];
    }

    std::vector<uint8_t> nsDataToByteVector(NSData *data) {
        if (!data || data.length == 0) return {};

        const uint8_t *bytes = static_cast<const uint8_t*>(data.bytes);
        return std::vector<uint8_t>(bytes, bytes + data.length);
    }

    NSData* byteVectorToNSData(const std::vector<uint8_t> &byteVector) {
        if (byteVector.empty()) return [NSData data];
        return [NSData dataWithBytes:byteVector.data() length:byteVector.size()];
    }

    std::vector<std::string> nsStringArrayToStdVector(NSArray<NSString*> *array) {
        std::vector<std::string> result;
        if (!array) return result;

        for (NSString *str in array) {
            result.push_back(nsStringToStdString(str));
        }
        return result;
    }

    NSArray<NSString*>* stdVectorToNSStringArray(const std::vector<std::string> &stringVector) {
        NSMutableArray<NSString*> *array = [NSMutableArray arrayWithCapacity:stringVector.size()];
        for (const auto &str : stringVector) {
            [array addObject:stdStringToNSString(str)];
        }
        return [array copy];
    }

    std::map<std::string, std::string> nsDictionaryToStdMap(NSDictionary<NSString*, NSString*> *dict) {
        std::map<std::string, std::string> result;
        if (!dict) return result;

        for (NSString *key in dict) {
            result[nsStringToStdString(key)] = nsStringToStdString(dict[key]);
        }
        return result;
    }

    NSDictionary<NSString*, NSString*>* stdMapToNSDictionary(const std::map<std::string, std::string> &stringMap) {
        NSMutableDictionary<NSString*, NSString*> *dict = [NSMutableDictionary dictionaryWithCapacity:stringMap.size()];
        for (const auto &pair : stringMap) {
            dict[stdStringToNSString(pair.first)] = stdStringToNSString(pair.second);
        }
        return [dict copy];
    }
}
