//
//  CAsyncCaller.h
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 12/06/25.
//

#ifndef CAsyncCaller_h
#define CAsyncCaller_h


#endif /* CAsyncCaller_h */


#import <Foundation/Foundation.h>

typedef void (^AsyncCompletion)(NSString * result,
                                NSError * error);

@protocol CAsyncCallbackDelegate <NSObject>
- (void)didReceiveData:(NSData *)data error:(NSError *)error;
- (void)didReceiveString:(NSString *)str error:(NSError *)error;
@end

@interface CAsyncCaller : NSObject

@property (weak, nonatomic) id<CAsyncCallbackDelegate> delegate;

- (void)startAsyncOperation;
- (void)performAsyncOperationWithInput:(NSData *)input
                            completion:(AsyncCompletion)completion;

- (void)sampleCallBackRequest:(NSString *)inputStr
                            completion:(AsyncCompletion)completion;

@end
