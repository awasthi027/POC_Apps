//
//  AAPKCS12Helper.m
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

#import "AAPKCS12Helper.h"
#import <openssl/pkcs12.h>

@interface AAPKCS12Helper()

@property (nonatomic, assign) EVP_PKEY *publicKey;
@property (nonatomic, assign) EVP_PKEY *privateKey;

@end

@implementation AAPKCS12Helper

- (instancetype)init:(NSString *) p12CertPath
        certPassword:(NSString *) certPassword {
    self = [super init];
    if (self) {
        // Extract keys
           EVP_PKEY *publicKey = NULL;
           EVP_PKEY *privateKey = NULL;
           if (![self extractKeysFromP12:p12CertPath
                                password: certPassword
                               publicKey:&publicKey
                              privateKey:&privateKey]) {
               NSLog(@"Not able get public and privateKeyFrom certificate");
           }
        self.publicKey = publicKey;
        self.privateKey = privateKey;
    }
    return self;
}

- (BOOL)extractKeysFromP12:(NSString *)p12FilePath
                  password:(NSString *)password
                 publicKey:(EVP_PKEY **)publicKey
                privateKey:(EVP_PKEY **)privateKey {
    FILE *fp = fopen([p12FilePath UTF8String], "rb");
    if (!fp) {
        NSLog(@"Failed to open .p12 file");
        return NO;
    }

    // Load the .p12 file
    PKCS12 *p12 = d2i_PKCS12_fp(fp, NULL);
    fclose(fp);

    if (!p12) {
        NSLog(@"Failed to parse .p12 file");
        return NO;
    }

    // Extract keys
    X509 *cert = NULL;
    STACK_OF(X509) *ca = NULL;
    const char *passwordString = password.UTF8String;
    if (!PKCS12_parse(p12, passwordString, privateKey, &cert, &ca)) {
        NSLog(@"Failed to parse .p12 file (incorrect password?)");
        PKCS12_free(p12);
        return NO;
    }

    // Extract public key from the certificate
    if (cert) {
        *publicKey = X509_get_pubkey(cert);
        if (!*publicKey) {
            NSLog(@"Failed to extract public key from certificate");
            X509_free(cert);
            PKCS12_free(p12);
            return NO;
        }
    }

    // Clean up
    X509_free(cert);
    sk_X509_pop_free(ca, X509_free);
    PKCS12_free(p12);

    return YES;
}
- (NSData *)encryptMessage:(NSString *)message {
    return  [self encryptMessage: message
                   withPublicKey:self.publicKey];
}

- (NSString *)decryptData:(NSData *)data {
    return  [self decryptMessage: data
                  withPrivateKey:self.privateKey];
}

- (NSData *)encryptMessage:(NSString *)message withPublicKey:(EVP_PKEY *)publicKey {
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(publicKey, NULL);
    if (!ctx) {
        NSLog(@"Failed to create context");
        return nil;
    }

    if (EVP_PKEY_encrypt_init(ctx) <= 0) {
        NSLog(@"Failed to initialize encryption");
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    const char *msg = [message UTF8String];
    size_t msg_len = strlen(msg);
    size_t outlen;

    // Determine buffer size
    if (EVP_PKEY_encrypt(ctx, NULL, &outlen, (unsigned char *)msg, msg_len) <= 0) {
        NSLog(@"Failed to determine buffer size");
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    // Encrypt the message
    unsigned char *encrypted = malloc(outlen);
    if (EVP_PKEY_encrypt(ctx, encrypted, &outlen, (unsigned char *)msg, msg_len) <= 0) {
        NSLog(@"Failed to encrypt message");
        free(encrypted);
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    EVP_PKEY_CTX_free(ctx);

    NSData *encryptedData = [NSData dataWithBytes:encrypted length:outlen];
    free(encrypted);

    return encryptedData;
}
- (NSString *)decryptMessage:(NSData *)encryptedData withPrivateKey:(EVP_PKEY *)privateKey {
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(privateKey, NULL);
    if (!ctx) {
        NSLog(@"Failed to create context");
        return nil;
    }

    if (EVP_PKEY_decrypt_init(ctx) <= 0) {
        NSLog(@"Failed to initialize decryption");
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    size_t outlen;

    // Determine buffer size
    if (EVP_PKEY_decrypt(ctx, NULL, &outlen, [encryptedData bytes], [encryptedData length]) <= 0) {
        NSLog(@"Failed to determine buffer size");
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    // Decrypt the message
    unsigned char *decrypted = malloc(outlen);
    if (EVP_PKEY_decrypt(ctx, decrypted, &outlen, [encryptedData bytes], [encryptedData length]) <= 0) {
        NSLog(@"Failed to decrypt message");
        free(decrypted);
        EVP_PKEY_CTX_free(ctx);
        return nil;
    }

    EVP_PKEY_CTX_free(ctx);

    NSString *decryptedMessage = [[NSString alloc] initWithBytes:decrypted length:outlen encoding:NSUTF8StringEncoding];
    free(decrypted);

    return decryptedMessage;
}

@end
