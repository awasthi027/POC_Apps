//
//  ObjCAsyncCommunication.h
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 10/06/25.
//

#import <Foundation/Foundation.h>
typedef void (^CompleteRequest)(NSInteger result, NSString *error);
@interface CPlusPlusAsyncCommunication: NSObject
- (void)addNumber:(int)firstNumber
                           second:(int) secondNumber
                  completeHandler:(CompleteRequest)completion;
- (void)multipleCallBack:(int)value
         completeHandler:(CompleteRequest)completion;

- (void)setupCallbacks:(int) code
                  completeHandler:(CompleteRequest)completion;
@end
