//
//  AAPKCS12Helper.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 02/02/25.
//
#import "AAPKCS12Helper.h"


// Function to sign message using private key
NSData *signMessageWithPrivateKey(EVP_PKEY *privKey, NSData *message) {
    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    if (!mdctx) {
        NSLog(@"Failed to create message digest context.");
        return nil;
    }
    // Hash data with algo sh256
    if (EVP_DigestSignInit(mdctx, NULL, EVP_sha256(), NULL, privKey) <= 0) {
        NSLog(@"Failed to initialize digest sign context.");
        EVP_MD_CTX_free(mdctx);
        return nil;
    }

    if (EVP_DigestSignUpdate(mdctx, [message bytes], [message length]) <= 0) {
        NSLog(@"Failed to update digest sign context.");
        EVP_MD_CTX_free(mdctx);
        return nil;
    }

    size_t sigLen = 0;
    if (EVP_DigestSignFinal(mdctx, NULL, &sigLen) <= 0) {
        NSLog(@"Failed to finalize digest sign context.");
        EVP_MD_CTX_free(mdctx);
        return nil;
    }

    unsigned char *sig = (unsigned char *)malloc(sigLen);
    if (!sig) {
        NSLog(@"Failed to allocate memory for signature.");
        EVP_MD_CTX_free(mdctx);
        return nil;
    }
    // Sign Hash data
    if (EVP_DigestSignFinal(mdctx, sig, &sigLen) <= 0) {
        NSLog(@"Failed to obtain signature.");
        EVP_MD_CTX_free(mdctx);
        free(sig);
        return nil;
    }

    EVP_MD_CTX_free(mdctx);

    return [NSData dataWithBytes:sig length:sigLen];
}

// Function to verify signature using public key
BOOL verifySignatureWithPublicKey(EVP_PKEY *pubKey, NSData *message, NSData *signature) {
    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    if (!mdctx) {
        NSLog(@"Failed to create message digest context.");
        return NO;
    }

    if (EVP_DigestVerifyInit(mdctx, NULL, EVP_sha256(), NULL, pubKey) <= 0) {
        NSLog(@"Failed to initialize digest verify context.");
        EVP_MD_CTX_free(mdctx);
        return NO;
    }
     // Digesting Message
    if (EVP_DigestVerifyUpdate(mdctx, [message bytes], [message length]) <= 0) {
        NSLog(@"Failed to update digest verify context.");
        EVP_MD_CTX_free(mdctx);
        return NO;
    }
    // Here decrpt signature and compare has with message hash
    int result = EVP_DigestVerifyFinal(mdctx, [signature bytes], [signature length]);
    EVP_MD_CTX_free(mdctx);

    return result == 1;
}

/*
 1. Hash Message, Choose any algorthim for hashing message ex: EVP_sha256
 2. Encrypt message with Public or private key, From You will get Signature
 3. Verify Signature, Send Public key or priviate key, actual message, Signature
 4. Hash Actual Message with same algorthim
 5. Decrypt Signature and get Hash of message
 6. Verify both hash
*/

