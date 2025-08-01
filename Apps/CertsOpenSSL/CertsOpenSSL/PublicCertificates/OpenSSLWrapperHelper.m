//
//  OpenSSLWrapperHelper.m
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

#import <Foundation/Foundation.h>
#import "OpenSSLWrapperHelper.h"
#include <OpenSSL/rand.h>
#include <OpenSSL/pem.h>
#include <OpenSSL/err.h>

#define kAWPKCS8Cipher EVP_aes_128_cbc()

BIO * _Nullable AAGetBIOForData(NSData * _Nonnull data) {
    if(data == nil) {
        return nil;
    }
    BIO *writeBio = BIO_new(BIO_s_mem());
    BIO_write(writeBio, data.bytes, (int)data.length);
    return writeBio;
}


NSRecursiveLock* _openssl_lock(void) {
    static NSRecursiveLock *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSRecursiveLock alloc] init];
    });

    return lock;
}


//All Public methods must be using this method to make them Thread Safe. Remember that, the method will become non-reentrant.
void enter_open_ssl(void) {
    NSRecursiveLock *lock = _openssl_lock();
    [lock lock];
}

void exit_open_ssl(void) {
    NSRecursiveLock *lock = _openssl_lock();
    [lock unlock];
}

SecCertificateRef readSecCertificateFromP12(NSString *p12Path,
                                  NSString *password,
                                  NSData * fileData) {
    // Load the .p12 file
    NSData *p12Data = fileData;
    // Create a dictionary for import options
    NSDictionary *options = @{
        (__bridge id)kSecImportExportPassphrase: password
    };

    // Import the .p12 data
    CFArrayRef items = NULL;
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)p12Data, (__bridge CFDictionaryRef)options, &items);
    if (status != errSecSuccess) {
        NSLog(@"Failed to import .p12 file. Error: %d", (int)status);
        return nil;
    }

    // Extract the identity and certificate
    CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
    SecIdentityRef identity = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
    if (!identity) {
        NSLog(@"Failed to extract identity from .p12 file.");
        return nil;
    }

    SecCertificateRef certificate = NULL;
    status = SecIdentityCopyCertificate(identity, &certificate);
    if (status != errSecSuccess || !certificate) {
        NSLog(@"Failed to extract certificate from identity. Error: %d", (int)status);
        return nil;
    }
    if (items) CFRelease(items);

    return certificate;
}

NSString * readSubjectNameFromP12(SecCertificateRef certificate) {
    // Get the subject name from the certificate
    CFStringRef subjectSummary = SecCertificateCopySubjectSummary(certificate);
    if (subjectSummary) {
        NSLog(@"Subject Name: %@", (__bridge NSString *)subjectSummary);
    } else {
        NSLog(@"Failed to extract subject name from certificate.");
    }
    return (NSString *)CFBridgingRelease(subjectSummary);
}


X509 * createX509FromCertificateData(NSData * data) {

    NSError *pemError = nil;
    NSError *derError = nil;
    BIO *certificateBIO = AAGetBIOForData(data);
    X509 *x509Cert = PEM_read_bio_X509(certificateBIO, NULL, 0, NULL);
    BIO_free(certificateBIO);

    if (x509Cert == nil) {;
        certificateBIO = AAGetBIOForData(data);;
        x509Cert = d2i_X509_bio(certificateBIO, NULL);
        BIO_free(certificateBIO);
    }
    if (x509Cert == nil) {
        NSLog(@"Error trying to parse as PEM: %@", pemError);
        NSLog(@"Error trying to parse as DER: %@", derError);
    }
    return x509Cert ;
}

NSString * stringFromX509Name(X509_NAME *name) {
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio) {
        return nil;
    }

    X509_NAME_print_ex(bio, name, 0, XN_FLAG_RFC2253);
    char buffer[1024];
    int len = BIO_read(bio, buffer, sizeof(buffer) - 1);
    BIO_free(bio);

    if (len <= 0) {
        return nil;
    }
    buffer[len] = '\0';
    return [NSString stringWithUTF8String:buffer];
}

NSString * stringFromASN1Time(ASN1_TIME *time) {
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio) {
        return nil;
    }
    ASN1_TIME_print(bio, time);
    char buffer[1024];
    int len = BIO_read(bio, buffer, sizeof(buffer) - 1);
    BIO_free(bio);

    if (len <= 0) {
        return nil;
    }
    buffer[len] = '\0';
    return [NSString stringWithUTF8String:buffer];
}


NSData *AAGetDataFromBIO(BIO *bio)
{
    NSData *returnData  = nil;

    if (bio != nil) {
        int num_write = (int)BIO_number_written(bio);
        char *buff = (char *)malloc(num_write);
        BIO_read(bio, buff, (int)(num_write));
        returnData  = [NSData dataWithBytes:buff length:num_write];
        free(buff);
    }

    return returnData;
}

NSError *AAGetOpenSSLError(void) {
    NSError *retErr = nil;
    unsigned long e = ERR_get_error();
    NSMutableString *errString = [NSMutableString string];
    while ((e = ERR_get_error()) != 0) {
        char *errstring = ERR_error_string(e, NULL);
        [errString appendString: [NSString stringWithFormat:@"%s", errstring]];
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:errString forKey:NSLocalizedDescriptionKey];
    retErr = [NSError errorWithDomain:@"aa.sdk.openssl" code:e userInfo:userInfo];
    return retErr;
}

NSString *AAGetStringFromBIO(BIO *bio) {
    NSString *returnString = nil;

    if (bio != nil) {
        int bytesWritten = (int)BIO_number_written(bio);
        int size = bytesWritten + 1;
        char *buff = (char *)malloc(size);
        memset(buff, 0, size);
        BIO_read(bio, buff, size);
        returnString = [[NSString alloc] initWithFormat: @"%s", buff];
        free(buff);
    }
    return returnString;
}

NSString * _Nullable AAGetX509ExtensionValue(X509_EXTENSION * _Nullable extension)
{
    NSString *value = nil;

    if (extension != NULL) {
        BIO *outBio = BIO_new(BIO_s_mem());
        if(X509V3_EXT_print(outBio, extension, 0, 0) > 0) {
            value = AAGetStringFromBIO(outBio);
        }
        BIO_free(outBio);
    }

    return value;
}

EVP_PKEY *AAGetRSAPublicKey(NSData *publicKey) {
    if (publicKey == nil) {
        return NULL;
    }
    /* Check if the key is in PEM format */
    BIO *publicKeyBIO = AAGetBIOForData(publicKey);
    EVP_PKEY *pkey = PEM_read_bio_PUBKEY(publicKeyBIO, NULL, NULL, NULL);
    if (pkey == NULL) {
        /* Check if the key can be read using DER parser */
        const unsigned char *bytes = (unsigned char *)publicKey.bytes;
        pkey = d2i_PublicKey(EVP_PKEY_RSA, NULL, &bytes, publicKey.length);
    }

    BIO_free(publicKeyBIO);
    return pkey;
}

BOOL AAGenerateRSAKeyPair(int keySizeInBits, NSData **publicKey, NSData **privateKey) {
 
    if(publicKey == nil || privateKey == nil) {
        return NO;
    }

    enter_open_ssl();
    EVP_PKEY *rsaKeyPair = EVP_RSA_gen(keySizeInBits);

    if (rsaKeyPair == NULL) {
        return NO;
    }

    /* Read Private Key */
    BIO *bio = BIO_new(BIO_s_mem());
    PEM_write_bio_PrivateKey(bio, rsaKeyPair, NULL, NULL, 0, NULL, NULL);
    int keylen = BIO_pending(bio);
    void *pem_key = malloc(keylen);
    memset(pem_key, 0, keylen);
    BIO_read(bio, pem_key, keylen);
    BIO_free_all(bio);
    NSData *privateKeyData = [[NSData alloc] initWithBytesNoCopy:pem_key length:keylen freeWhenDone:YES];

    /* Read public Key */
    bio = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(bio, rsaKeyPair);
    keylen = BIO_pending(bio);
    pem_key = malloc(keylen);
    memset(pem_key, 0, keylen);
    BIO_read(bio, pem_key, keylen);
    BIO_free_all(bio);
    NSData *publicKeyData = [[NSData alloc] initWithBytesNoCopy:pem_key length:keylen freeWhenDone:YES];

    if (privateKey) {
        *privateKey = privateKeyData;
    }
    if(publicKey) {
        *publicKey = publicKeyData;
    }

    BOOL result = ((*publicKey).length > 0 && (*privateKey).length > 0);
    exit_open_ssl();
    return result;
}

//=====// Not using======
void AAEnableFIPSMode(void) {
    if (EVP_default_properties_is_fips_enabled(NULL) == false ) {
        EVP_default_properties_enable_fips(NULL, 1);
    }
}

void AADisableFIPSMode(void) {
    if (EVP_default_properties_is_fips_enabled(NULL)) {
        EVP_default_properties_enable_fips(NULL, 0);
    }
}

BOOL isFIPSHooksEnabled(void) {
    return EVP_default_properties_is_fips_enabled(NULL);
}
//=====// Not using======

NSData *AAGetDataFromPKCS12(PKCS12 *pkcs12)
{
    BIO *p12Bio = BIO_new(BIO_s_mem());

    i2d_PKCS12_bio(p12Bio, pkcs12);

    NSData *returnData = AAGetDataFromBIO(p12Bio);
    BIO_free(p12Bio);
    return returnData;
}

PKCS12 *AAGetPKCS12FromData(NSData *data)
{
    BIO *p12BIO = AAGetBIOForData(data);
    if(p12BIO == nil) {
        return nil;
    }
    PKCS12 *p12 = d2i_PKCS12_bio(p12BIO, NULL);
    BIO_free(p12BIO);
    return p12;
}

BOOL AAPKCS12Parse(NSData *p12Data, NSString *password, EVP_PKEY **pkey, X509 **cert)
{
    if (password == NULL || p12Data.length == 0) {
        return NO;
    }

    PKCS12 *p12 = AAGetPKCS12FromData(p12Data);
    if (p12 == NULL) {
        return NO;
    }

    if (PKCS12_mac_present(p12) == false) {
        PKCS12_free(p12);
        return NO;
    }

    const X509_ALGOR *macalg;
    const ASN1_OBJECT *macoid;

    PKCS12_get0_mac(NULL, &macalg, NULL, NULL, p12);
    //https://github.com/openssl/openssl/issues/19997
    //    Unlike in 1.x.y, the PKCS12KDF algorithm used when a PKCS#12 structure is created with a MAC
    //    that does not work with the FIPS provider as the PKCS12KDF is not a FIPS approvable mechanism.
    X509_ALGOR_get0(&macoid, NULL, NULL, macalg);
    if (OBJ_obj2nid(macoid) != NID_pbmac1) {
        AADisableFIPSMode();
    }

    const char *passwordString = password.UTF8String;
    if (PKCS12_verify_mac(p12, passwordString, (int)strlen(passwordString)) == 0) {
        NSLog(@"MAC verficiation failed: error %@", AAGetOpenSSLError());
        PKCS12_free(p12);
        AAEnableFIPSMode();
        return NO;
    }
    if(PKCS12_parse(p12, passwordString, pkey, cert, NULL) != 1) {
        NSLog(@"Private Key Read failed: error %@", AAGetOpenSSLError());
        PKCS12_free(p12);
        AAEnableFIPSMode();
        return NO;
    }
    AAEnableFIPSMode();
    return YES;
}

NSData *AAPKCS12UpdatePassword(NSData *p12Data, NSString *oldPassword, NSString *newPassword)
{
    NSData *returnData = nil;

    if (oldPassword == NULL || newPassword == NULL || newPassword.length == 0) {
        return returnData;
    }

    PKCS12 *p12 = AAGetPKCS12FromData(p12Data);
    if (p12 == NULL) {
        return returnData;
    }

    const char *oldPasswordString = oldPassword.UTF8String;
    const char *newPasswordString = newPassword.UTF8String;

    if (PKCS12_mac_present(p12)) {
        const X509_ALGOR *macalg;
        const ASN1_OBJECT *macoid;
        PKCS12_get0_mac(NULL, &macalg, NULL, NULL, p12);
        X509_ALGOR_get0(&macoid, NULL, NULL, macalg);
        if (OBJ_obj2nid(macoid) != NID_pbmac1) {
         //   AWDisableFIPSMode();
        }
    }

    if (PKCS12_newpass(p12, oldPasswordString, newPasswordString) == 0) {
        NSLog(@"Update password failed: error %@", AAGetOpenSSLError());
        PKCS12_free(p12);
       // AAEnableFIPSMode();
        return returnData;
    }
  //  AAEnableFIPSMode();
    returnData = AAGetDataFromPKCS12(p12);
    PKCS12_free(p12);
    return returnData;
}

NSData* changeP12PasswordAndGetData(NSData *p12Data,
                                    NSString *oldPassword,
                                    NSString *newPassword,
                                    NSError **error) {
    BIO *p12Bio = BIO_new_mem_buf((void *)p12Data.bytes, (int)p12Data.length);
    if (!p12Bio) {
        *error = [NSError errorWithDomain:@"OpenSSL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create BIO from p12 data."}];
        return nil;
    }

    PKCS12 *p12 = d2i_PKCS12_bio(p12Bio, NULL);
    BIO_free(p12Bio);

    if (!p12) {
        ERR_load_crypto_strings();
        char err_buf[256];
        ERR_error_string_n(ERR_get_error(), err_buf, sizeof(err_buf));
        NSString *errString = [NSString stringWithUTF8String:err_buf];
        *error = [NSError errorWithDomain:@"OpenSSL" code:-2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to parse PKCS12 data: %@", errString]}];
        return nil;
    }

    PKCS12 *newP12 = PKCS12_newpass(p12, [oldPassword UTF8String], [newPassword UTF8String]);
    PKCS12_free(p12);

    if (!newP12) {
        ERR_load_crypto_strings();
        char err_buf[256];
        ERR_error_string_n(ERR_get_error(), err_buf, sizeof(err_buf));
        NSString *errString = [NSString stringWithUTF8String:err_buf];
        *error = [NSError errorWithDomain:@"OpenSSL" code:-3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to change password: %@", errString]}];
        PKCS12_free(newP12); // Free it before returning nil
        return nil;
    }

    BIO *newP12Bio = BIO_new(BIO_s_mem());
    if (!newP12Bio) {
        *error = [NSError errorWithDomain:@"OpenSSL" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create BIO for new p12 data."}];
        PKCS12_free(newP12);
        return nil;
    }

    i2d_PKCS12_bio(newP12Bio, newP12);
    PKCS12_free(newP12);

    BUF_MEM *memPtr;
    BIO_get_mem_ptr(newP12Bio, &memPtr);
    NSData *newP12Data = [NSData dataWithBytes:memPtr->data length:memPtr->length];

    BIO_free(newP12Bio);

    return newP12Data;
}
