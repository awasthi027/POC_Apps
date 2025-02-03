//
//  AAPKCS12.h
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

#import <Foundation/Foundation.h>
#import <openssl/pkcs12.h>
#import "AAPKCS12Helper.h"

@interface AAPKCS12: NSObject

/// Create instance of OPEN SSL Wrapper class
/// - Parameters:
///   - p12CertPath: Certificate file path
///   - certPassword: Certicate password
- (instancetype)init:(NSString *) p12CertPath
            certPassword:(NSString *) certPassword;

- (NSData *)encryptMessage:(NSString *)message;

- (NSString *)decryptData:(NSData *)data;

- (NSData *)signMessage: (NSString *)message;

- (Boolean )verifySignature: (NSData *)signature
                                message: (NSString *)message;
@end
