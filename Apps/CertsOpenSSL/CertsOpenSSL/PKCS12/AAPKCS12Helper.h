//
//  AAPKCS12Helper.h
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

#import <Foundation/Foundation.h>

@interface AAPKCS12Helper: NSObject

/// Create instance of OPEN SSL Wrapper class
/// - Parameters:
///   - p12CertPath: Certificate file path
///   - certPassword: Certicate password
- (instancetype)init:(NSString *) p12CertPath
            certPassword:(NSString *) certPassword;

- (NSData *)encryptMessage:(NSString *)message;

- (NSString *)decryptData:(NSData *)data;

@end
