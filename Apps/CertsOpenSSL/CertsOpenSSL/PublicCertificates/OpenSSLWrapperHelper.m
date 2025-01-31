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

BIO * _Nullable AWGetBIOForData(NSData * _Nonnull data) {
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
    BIO *certificateBIO = AWGetBIOForData(data);
    X509 *x509Cert = PEM_read_bio_X509(certificateBIO, NULL, 0, NULL);
    BIO_free(certificateBIO);

    if (x509Cert == nil) {;
        certificateBIO = AWGetBIOForData(data);;
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
    BIO *publicKeyBIO = AWGetBIOForData(publicKey);
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


