//
//  OpenSSLWrapperHelper.h
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

#import <Security/Security.h>
#import <openssl/pkcs12.h>
#import <openssl/x509.h>
#import <openssl/err.h>
#include <OpenSSL/x509v3.h>

SecCertificateRef readSecCertificateFromP12(NSString *p12Path,
                                  NSString *password,
                                             NSData * fileData);

NSString * readSubjectNameFromP12(SecCertificateRef certificate);

X509 * createX509FromCertificateData(NSData * data);

NSString * stringFromASN1Time(ASN1_TIME *time);
NSString * stringFromX509Name(X509_NAME *name);

NSData *AAGetDataFromBIO(BIO *bio);
NSError *AAGetOpenSSLError(void);
NSString *AAGetX509ExtensionValue(X509_EXTENSION * extension);
EVP_PKEY *AAGetRSAPublicKey(NSData *publicKey);
/// Generate public and private key
BOOL AAGenerateRSAKeyPair(int keySizeInBits, NSData **publicKey, NSData **privateKey);

BIO * _Nullable AAGetBIOForData(NSData * _Nonnull data);

void enter_open_ssl(void);
void exit_open_ssl(void);

// Not using
BOOL isFIPSHooksEnabled(void);
void AAEnableFIPSMode(void);
void AADisableFIPSMode(void);

// Check whether certificate is valid or not
BOOL AAPKCS12Parse(NSData *p12Data, NSString *password, EVP_PKEY **pkey, X509 **cert);
// Change certificate password
NSData *AAPKCS12UpdatePassword(NSData *p12Data, NSString *oldPassword, NSString *newPassword);

