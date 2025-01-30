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

void enter_open_ssl(void);
void exit_open_ssl(void);






