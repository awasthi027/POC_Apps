//
//  OpenSSLWrapper.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

#import <Foundation/Foundation.h>
#import <OpenSSL/OpenSSL.h>

typedef NS_ENUM(NSUInteger, KeyUsage) {
    DigitalSignature    = 1 << 7,
    NonRepudiation      = 1 << 6,
    KeyEncipherment     = 1 << 5,
    DataEncipherment    = 1 << 4,
    KeyAgreement        = 1 << 3,
    KeyCertSign         = 1 << 2,
    CrlSign             = 1 << 1,
    EncipherOnly        = 1 << 0,
    DecipherOnly        = 1 << 15
};

typedef NS_ENUM(NSUInteger, ExtendedKeyUsage) {
    SSL_Server  = 1 << 0,
    SSL_Client  = 1 << 1,
    SMIME       = 1 << 2,
    CodeSign    = 1 << 3,
    SGC         = 1 << 4,
    OCSPSign    = 1 << 5,
    TimeStamp   = 1 << 6,
    DVCS        = 1 << 7,
    AnyEKU      = 1 << 8
};

@interface CreateKeys : NSObject

@property (nonatomic, assign) NSData *publicKey;
@property (nonatomic, assign) NSData *privateKey;

@end

@interface OpenSSLWrapper : NSObject

/// Create instance of OPEN SSL Wrapper class
/// - Parameters:
///   - p12CertPath: Certificate file path
///   - certPassword: Certicate password
- (instancetype)init:(NSString *) p12CertPath
            certPassword:(NSString *) certPassword;

/// Create instance of OPEN SSL Wrapper class
/// - Parameters:
///   - attributes: Send atttributes
///   - publicKey: public data
- (instancetype) initWithAttributes:(NSDictionary* )attributes
                          publicKey:(NSData* )publicKey;

/// Create keys
+ (CreateKeys *)createPublicKeyAndGetData;

/// create certificate by giving required parameters
/// - Parameters:
///   - certPassword: certificate password
///   - certName: certificate name
///   - subjectName: certificate subject name
///   - fileName: certificate file name
+ (NSString *)generateP12Certificate:(NSString *) certPassword
                      certName:(NSString *) certName
                      subjectName:(NSString *) subjectName
                      fileName:(NSString *) fileName;
/// Read certificate subject name
- (NSString *)readSubjectNameFromCert;
/// Read certificate issue date
- (NSString *)readCertificateIssueDate;
/// read certificate expiry date
- (NSString *)readCertificateExpiryDate;
/// check whether we can use this for certification operation purpose or not
- (BOOL )canUseFor:(KeyUsage)usage;
/// check whether we can use this for certification operation purpose or not
- (BOOL )hasExtendedUsage:(ExtendedKeyUsage)eUsage;
/// check certificate is valid or not
- (BOOL )isValid;
/// Export certificate data
- (NSData *) exportCertificateData;
/// is this certificate root certificate
- (BOOL) isRootCA;
/// get certificate description
- (NSString *)certDescription;

@end
