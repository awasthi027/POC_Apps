//
//  ObjCppUtils.h
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/06/25.
//

#ifndef ObjCppUtils_h
#define ObjCppUtils_h


#endif /* ObjCppUtils_h */
#import <Foundation/Foundation.h>
#include <string>
#include <vector>
#include <map>

struct CBuffer {
    const void *data;
    size_t length;
};

struct CString {
    const char *cString;
    size_t length;
};

CBuffer nsDataToCBuffer(NSData *nsData);
NSData* cBufferToNSData(CBuffer buffer);
NSString* cBufferToNSString(CBuffer buffer);
CString cStringFromCBuffer(CBuffer buffer);
CString cStringFromNSString(NSString *nsStr);
NSString* nsStringFromCString(const char *result);
NSData* nsDatFromCData(CBuffer buffer);

namespace ObjCppUtils {
// NSString -> std::string
   std::string nsStringToStdString(NSString *nsString);

   // std::string -> NSString
   NSString* stdStringToNSString(const std::string &stdString);

   // NSData -> std::vector<uint8_t>
   std::vector<uint8_t> nsDataToByteVector(NSData *data);

   // std::vector<uint8_t> -> NSData
   NSData* byteVectorToNSData(const std::vector<uint8_t> &byteVector);

   // NSArray<NSString*> -> std::vector<std::string>
   std::vector<std::string> nsStringArrayToStdVector(NSArray<NSString*> *array);

   // std::vector<std::string> -> NSArray<NSString*>
   NSArray<NSString*>* stdVectorToNSStringArray(const std::vector<std::string> &stringVector);

   // NSDictionary -> std::map<std::string, std::string>
   std::map<std::string, std::string> nsDictionaryToStdMap(NSDictionary<NSString*, NSString*> *dict);

   // std::map<std::string, std::string> -> NSDictionary
   NSDictionary<NSString*, NSString*>* stdMapToNSDictionary(const std::map<std::string, std::string> &stringMap);
}
