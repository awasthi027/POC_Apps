//
//  OpenSSLWrapper.m
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

#import "OpenSSLWrapper.h"
#import "OpenSSLWrapperHelper.h"
#import <openssl/x509.h>
#import <openssl/evp.h>

NSString *kAACertificateSubjectName = @"AACertificateSubjectName";
NSString *kAACertificateUserID      = @"AAUserID";
NSString *kAACertificateValidity    = @"AACertificateValidity";
NSString *kAAEmailId                = @"AAEmailId";

@implementation CreateKeys

- (instancetype)init:(NSData *) publicKey
          privateKey:(NSData *) privateKey {
    self.publicKey = publicKey;
    self.privateKey = privateKey;
    return self;
}

@end

@interface OpenSSLWrapper()
@property (nonatomic, assign) SecCertificateRef secCertificate;
@property (nonatomic, assign) X509 *x509Cert;
@property (nonatomic, assign) EVP_PKEY *publicKey;
@property (nonatomic, assign) EVP_PKEY *privateKey;
@end

@implementation OpenSSLWrapper

- (instancetype)init:(NSString *) p12CertPath
        certPassword:(NSString *) certPassword {
    self = [super init];
    if (self) {
        NSData *p12Data = [OpenSSLWrapper readDataFromCertificateFile: p12CertPath
                                                     certPassword: certPassword];
        self.secCertificate = readSecCertificateFromP12(p12CertPath,
                                                      certPassword,
                                                      p12Data);
        NSData *x509CertData = CFBridgingRelease(SecCertificateCopyData(self.secCertificate));

        self.x509Cert = createX509FromCertificateData(x509CertData);
        self.publicKey = [self extractPublicKeyFromCertificate: self.secCertificate];
        self.privateKey = [self extractPrivateKeyFromPKCS12: p12Data
                                 password: certPassword];
    }
    return self;
}

- (instancetype) initWithAttributes:(NSDictionary* )attributes
                          publicKey:(NSData* )publicKey {
    if (publicKey == nil) {
        return nil;
    }

    NSString *commonName = attributes[kAACertificateSubjectName];
    if (commonName.length <= 0 ) {
        return nil;
    } else if (commonName.length > 64) { // Maximum length of 64 according to RFC 528
        commonName = [commonName substringToIndex: 64];
    }

    NSString *userID = attributes[kAACertificateUserID];
    if (userID.length <= 0) {
        return nil;
    }

    NSString *interVal = attributes[kAACertificateValidity];
    long long interval = [interVal longLongValue];
    if (interval < 1) {
        interval = 10 * 365 * 24 * 60 * 60;  //10 years
    }

    enter_open_ssl();
    X509 *x509cert = X509_new();
    X509_set_version(x509cert, 2);

    // Random Serial Number
    uint8_t *serial = [OpenSSLWrapper generateRandomBytes: 16];

    ASN1_INTEGER *i = X509_get_serialNumber(x509cert);
    i->length = 16;
    i->data = serial;

    X509_gmtime_adj(X509_get_notBefore(x509cert), 0);
    X509_gmtime_adj(X509_get_notAfter(x509cert), (long)interval);


    X509_NAME *xname = X509_get_subject_name(x509cert);
    NSData *identifier = [userID dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cnData = [commonName dataUsingEncoding:NSUTF8StringEncoding];
    //NSData *emailData = [ dataUsingEncoding: NSUTF8StringEncoding];

    X509_NAME_add_entry_by_txt(xname, "UID", MBSTRING_UTF8, (unsigned char*)identifier.bytes, (int)identifier.length, -1, 0);
    X509_NAME_add_entry_by_txt(xname, "CN", MBSTRING_UTF8, (unsigned char*)cnData.bytes, (int)cnData.length, -1, 0);

    X509_set_issuer_name(x509cert, xname);

    NSString *emailId = attributes[kAAEmailId];
    // Add email address
    if (emailId.length > 0) {
        X509_NAME_add_entry_by_txt(xname, "emailAddress", MBSTRING_ASC, (unsigned char *)[emailId UTF8String], -1, -1, 0);
    }

    EVP_PKEY *pkey = AAGetRSAPublicKey(publicKey);
    if (pkey != NULL && X509_set_pubkey(x509cert, pkey) == 1) {
        self.x509Cert = x509cert;
    } else {
        if (x509cert != nil) {
            X509_free(x509cert);
        }
        NSError *returnError = AAGetOpenSSLError();
        NSLog(@"Cert Create Error %@", returnError);
    }

    EVP_PKEY_free(pkey);
    if (self.x509Cert == nil) {
        exit_open_ssl();
        return nil;
    }

    exit_open_ssl();
    return self;
}

+ (EVP_PKEY *)generateRSAKey {
    EVP_PKEY *pkey = NULL;
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);

    if (!ctx) {
        NSLog(@"Failed to create PKEY context.");
        ERR_print_errors_fp(stderr); // Print OpenSSL errors to standard error
        return NULL;
    }

    if (EVP_PKEY_keygen_init(ctx) <= 0) {
        NSLog(@"Failed to initialize keygen.");
        EVP_PKEY_CTX_free(ctx);
        ERR_print_errors_fp(stderr); // Print OpenSSL errors to standard error
        return NULL;
    }

    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0) {
        NSLog(@"Failed to set RSA key length.");
        EVP_PKEY_CTX_free(ctx);
        ERR_print_errors_fp(stderr); // Print OpenSSL errors to standard error
        return NULL;
    }

    if (EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        NSLog(@"Failed to generate RSA key.");
        EVP_PKEY_CTX_free(ctx);
        ERR_print_errors_fp(stderr); // Print OpenSSL errors to standard error
        return NULL;
    }

    EVP_PKEY_CTX_free(ctx);
    return pkey;
}


+(NSData *)readDataFromCertificateFile:(NSString *) p12CertPath
                          certPassword:(NSString *) certPassword {
    // Load the .p12 file
    NSData *p12Data = [NSData dataWithContentsOfFile: p12CertPath];
    if (!p12Data) {
        NSString *fileName = [p12CertPath componentsSeparatedByString:@"/"].lastObject;
        NSLog(@"Failed to load .p12 file from bundle fileName: %@",fileName);
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
        p12Data = [NSData dataWithContentsOfFile: filePath];
        if (!p12Data) {
            NSLog(@"Failed to load .p12 file from tmp directory.");
            return nil;
        }
    }
    return p12Data ;
}
- (NSData *) exportCertificateData {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    BIO *certBIO = BIO_new(BIO_s_mem());
    NSData *data = nil;
    if (i2d_X509_bio(certBIO, self.x509Cert) == 1) {
        data = AAGetDataFromBIO(certBIO);
    } else {
        NSLog(@"Export Cert Error: %@", AAGetOpenSSLError());
    }

    BIO_free(certBIO);
    exit_open_ssl();
    return data;
}

- (NSString *)readSubjectNameFromCert {
    // Get the subject name
    if (self.x509Cert) {
        enter_open_ssl();
        X509_NAME *subjectName = X509_get_subject_name(self.x509Cert);
        if (subjectName) {
            return stringFromX509Name(subjectName);
        } else {
            NSLog(@"Failed to extract subject name from certificate");
        }
        exit_open_ssl();
    }
    NSLog(@"Nil X509 certificate");
    return  nil;
}

- (NSString *)readCertificateIssueDate {
    // Get the start and end dates
    if (self.x509Cert) {
        enter_open_ssl();
        ASN1_TIME *notBefore = X509_get_notBefore(self.x509Cert);
        if (notBefore) {
            NSString *startDate = stringFromASN1Time(notBefore);
            NSLog(@"Start Date: %@", startDate);
            return startDate;
        } else {
            NSLog(@"Failed to extract subject name from certificate");
        }
        exit_open_ssl();
    }
    NSLog(@"Nil X509 certificate");
    return  nil;
}

- (NSString *)readCertificateExpiryDate {
    // Get the start and end dates
    if (self.x509Cert) {
        enter_open_ssl();
        ASN1_TIME *notAfter = X509_get_notAfter(self.x509Cert);
        if (notAfter) {
            NSString *startDate = stringFromASN1Time(notAfter);
            NSLog(@"Expiry date: %@", startDate);
            return startDate;
        } else {
            NSLog(@"Failed to extract subject name from certificate");
        }
        exit_open_ssl();
    }
    NSLog(@"Nil X509 certificate");
    return  nil;
}

- (BOOL) canUseFor:(KeyUsage)usage {
    if (self.x509Cert == nil) {
        return  NO;
    }
    enter_open_ssl();
    X509_check_ca(self.x509Cert);
    BOOL result = usage & X509_get_key_usage(self.x509Cert);
    exit_open_ssl();
    return result;
}

- (BOOL) hasExtendedUsage:(ExtendedKeyUsage)eUsage {
    if (self.x509Cert == nil) {
        return  NO;
    }
    enter_open_ssl();
    X509_check_ca(self.x509Cert);
    BOOL result = eUsage & X509_get_extended_key_usage(self.x509Cert);
    exit_open_ssl();
    return result;
}

- (BOOL )isValid {
    if (self.x509Cert == nil) {
        return  NO;
    }
    enter_open_ssl();
    const ASN1_TIME *afterTime = X509_get0_notAfter(self.x509Cert);
    BOOL result = (X509_cmp_current_time(afterTime) > 0);
    exit_open_ssl();
    return result;
}

- (NSString *)subjectName {
    return [self getAttributeAtIndex:1];
}

- (NSString *)subjectUserID {
    return [self getAttributeAtIndex:0];
}
- (NSString *)subjectIdentifier {
    return [self resultForExtensionWithNID:NID_subject_key_identifier];
}

- (X509_EXTENSION *)x509ExtensionWithNID:(int)nid {
    enter_open_ssl();
    X509_EXTENSION *extension = NULL;
    const STACK_OF(X509_EXTENSION) *extensions = X509_get0_extensions(self.x509Cert);
    for (int i=0; i<sk_X509_EXTENSION_num(extensions); i++) {

        X509_EXTENSION *ext = sk_X509_EXTENSION_value(extensions, i);
        if (OBJ_obj2nid(X509_EXTENSION_get_object(ext)) == nid) {
            extension = ext;
            break;
        }
    }

    exit_open_ssl();
    return extension;
}

- (NSString *)emailAddress {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    X509_NAME *subject = X509_get_subject_name(self.x509Cert);
    NSString *email = [[self entryFromX509Name:subject forKey:@"emailAddress"] firstObject];
    // If the email address is not available in the subject, check the altname
    if (email == nil) {
        STACK_OF(GENERAL_NAME) *altName = (STACK_OF(GENERAL_NAME) *)X509_get_ext_d2i(self.x509Cert, NID_subject_alt_name, NULL, NULL);
        if(altName != NULL) {
            email = [self nameFromX509AltName:altName type:GEN_EMAIL];
        }
        GENERAL_NAMES_free(altName);
    }
    exit_open_ssl();
    return email;
}

- (NSData *)serialNumber {
    if (self.x509Cert == nil) {
        return nil;
    }

    enter_open_ssl();
    ASN1_INTEGER *serial = X509_get_serialNumber(self.x509Cert);
    NSData* result = [NSData dataWithBytes:serial->data length:serial->length];
    exit_open_ssl();
    return result;
}

- (NSString *)issuerName {

    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    X509_NAME *issuerName = X509_get_issuer_name(self.x509Cert);
    NSString *issuer = [[self entryFromX509Name:issuerName
                                         forKey:@"organizationName"] firstObject];
    if(issuer == nil) {
        issuer = [[self entryFromX509Name: issuerName
                                   forKey: @"commonName"] firstObject];
    }
    exit_open_ssl();
    return issuer;
}
- (BOOL) isCACert {
    enter_open_ssl();
    // User openssl's CA Check method to verify if current Cert is CA Cert
    int result = X509_check_ca(self.x509Cert);
    exit_open_ssl();
    // Even though 2,3 and 4 seems to be representing CA certs, as per NIAP without Basic Constraints, it should not be used as CA.
    return (result == 1);
}

- (NSString *)commonName {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    X509_NAME *subject = X509_get_subject_name(self.x509Cert);
    NSString* result = [[self entryFromX509Name:subject forKey:@"commonName"] firstObject];
    exit_open_ssl();
    return result;
}

- (NSString *)algorithm {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    char buff[1024];
    const X509_ALGOR* sig_alg = X509_get0_tbs_sigalg(self.x509Cert);
    OBJ_obj2txt(buff, 1024, sig_alg->algorithm, 0);
    NSString* result = [NSString stringWithUTF8String:buff];
    exit_open_ssl();
    return result;
}

- (NSString *)universalPrincipalName {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    STACK_OF(GENERAL_NAME) *altName = (STACK_OF(GENERAL_NAME) *)X509_get_ext_d2i(self.x509Cert, NID_subject_alt_name, NULL, NULL);
    NSString *upn = nil;
    if(altName != NULL) {
        upn = [self nameFromX509AltName:altName type:GEN_OTHERNAME nid:NID_ms_upn];
    }
    GENERAL_NAMES_free(altName);
    exit_open_ssl();
    return upn;
}


- (NSArray<NSString *> *)ocspResponderList {
    NSMutableArray<NSString *> *list = [NSMutableArray new];
    STACK_OF(OPENSSL_STRING) *ocsp_list = X509_get1_ocsp(self.x509Cert);
    for (int i = 0; i < sk_OPENSSL_STRING_num(ocsp_list); i++) {
        NSString *s = [NSString stringWithUTF8String:sk_OPENSSL_STRING_value(ocsp_list, i)];
        if (s) {
            [list addObject:s];
        }
    }
    X509_email_free(ocsp_list);
    return list;
}

- (BOOL) isRootCA {
    enter_open_ssl();
    // User openssl's CA Check method to verify if current Cert is CA Cert
    int is_a_ca_cert = (X509_check_ca(self.x509Cert) == 1);
    BOOL is_self_signed_cert = [self isSignedByIssuer:self];

    NSString *subjectIdentifier = self.subjectIdentifier;
    NSString *authorityKeyIdentifier = [self.authorityKeyIdentifier stringByReplacingOccurrencesOfString:@"keyid:" withString:@""];
    BOOL is_self_authorized = (authorityKeyIdentifier == nil);
    if (subjectIdentifier != nil && authorityKeyIdentifier != nil) {
        is_self_authorized |= [subjectIdentifier isEqualToString:authorityKeyIdentifier];
    }

    exit_open_ssl();
    return (is_a_ca_cert                // Make sure the cert if CA cert...
            && is_self_signed_cert      // Make sure it is signed by itself...
            && is_self_authorized);     // Make sure it is authorizing itself...
}
- (BOOL) isSignedByIssuer:(OpenSSLWrapper* _Nonnull)issuerX509 {
    //A Non-CA cert can never be an issuer.
    if (issuerX509.isCACert == NO) {
        return NO;
    }

    enter_open_ssl();
    int result = X509_check_issued(issuerX509.x509Cert, self.x509Cert);
    exit_open_ssl();

    if(result != X509_V_OK){
        return NO;
    }

    return [self verifyWithRootCertificate: issuerX509];
}

/// get certificate decription
- (NSString *)certDescription {
    NSMutableString *decription = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"Subject Name: %@",[self readSubjectNameFromCert]]];
    [decription appendFormat:@"\n\nCertificate Purpose Types: %@",[self certificateUsePurpose]];
    [decription appendFormat:@"\nOCSOResponderList: %@",[self ocspResponderList]];
    [decription appendFormat:@"\nUniversalPrincipalName: %@",[self universalPrincipalName]];
    [decription appendFormat:@"\nAlgorithm: %@",[self algorithm]];
    [decription appendFormat:@"\nCommonName: %@",[self commonName]];
    [decription appendFormat:@"\nIsCACert: %d",[self isCACert]];
    [decription appendFormat:@"\nIssuerName: %@",[self issuerName]];
    [decription appendFormat:@"\nSerialNumber: %lu bytes",(unsigned long)[self serialNumber].length];
    [decription appendFormat:@"\nEmailAddress: %@",[self emailAddress]];
    [decription appendFormat:@"\nSubjectUserID: %@",[self subjectUserID]];
    [decription appendFormat:@"\nSubjectName: %@",[self subjectName]];
    [decription appendFormat:@"\nIsValid: %d",[self isValid]];
    [decription appendFormat:@"\nStart Date: %@",[self readCertificateIssueDate]];
    [decription appendFormat:@"\nExpiry Date: %@",[self readCertificateExpiryDate]];
    return decription ;
}


+ (NSString *)generateP12Certificate:(NSString *) certPassword
                      certName:(NSString *) certName
                      subjectName:(NSString *) subjectName
                      email:(NSString *) emailAddress
                      fileName:(NSString *) fileName {
    const char *cPass = [certPassword cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cCertName = [certName cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cSubjectName = [subjectName cStringUsingEncoding:NSUTF8StringEncoding];
    // Generate RSA Key
    EVP_PKEY *pkey = [OpenSSLWrapper generateRSAKey];

    // Create X509 Certificate
    X509 *x509 = X509_new();
    X509_set_version(x509, 2);
    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 31536000); // 1 year validity
    X509_set_pubkey(x509, pkey);

    // Random Serial Number
    uint8_t *serial = [OpenSSLWrapper generateRandomBytes: 16];
    ASN1_INTEGER *i = X509_get_serialNumber(x509);
    i->length = 16;
    i->data = serial;

    // Set Certificate Subject and Issuer
    X509_NAME *name = X509_get_subject_name(x509);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (unsigned char *)cSubjectName, -1, -1, 0);
    X509_set_issuer_name(x509, name);

    NSData *identifier = [@"XYX_UserId" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *commonName = [@"Ashish Awasthi Certificate" dataUsingEncoding:NSUTF8StringEncoding];
    //NSData *emailData = [ dataUsingEncoding: NSUTF8StringEncoding];

    X509_NAME_add_entry_by_txt(name, "UID", MBSTRING_UTF8, (unsigned char*)identifier.bytes, (int)identifier.length, -1, 0);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_UTF8, (unsigned char*)commonName.bytes, (int)commonName.length, -1, 0);

    X509_set_issuer_name(x509, name);

    NSString *emailId = emailAddress;
    // Add email address
    if (emailId.length > 0) {
        X509_NAME_add_entry_by_txt(name, "emailAddress", MBSTRING_ASC, (unsigned char *)[emailId UTF8String], -1, -1, 0);
    }
    // Sign the Certificate
    X509_sign(x509, pkey, EVP_sha256());

    // Create PKCS12 Structure
    PKCS12 *p12 = PKCS12_create(cPass, cCertName, pkey, x509, NULL, 0, 0, 0, 0, 0);
    if (!p12) {
        NSLog(@"Failed to create PKCS12 structure.");
        return @"";
    }

    // Write PKCS12 to File
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
    FILE *file = fopen([filePath UTF8String], "wb");
    if (!file) {
        NSLog(@"Failed to open file for writing.");
        return @"";
    }
    i2d_PKCS12_fp(file, p12);
    fclose(file);

    NSLog(@"P12 Certificate generated at: %@", filePath);
    // Cleanup
    PKCS12_free(p12);
    X509_free(x509);
    EVP_PKEY_free(pkey);
    return filePath;
}

+ (CreateKeys *)createPublicKeyAndPrivateKeyGetData {
    NSData *publicKey = nil;
    NSData *privateKey = nil;
    BOOL keyGenerated = AAGenerateRSAKeyPair(2048, &publicKey, &privateKey);
    NSLog(@"Is Key generated %d", keyGenerated);
    return  [[CreateKeys alloc]  init: publicKey privateKey: privateKey];;
}

- (void)dealloc {
    enter_open_ssl();
    if (self.x509Cert) {
        X509_free(self.x509Cert);
    }
    if (self.secCertificate) {
        CFRelease(self.secCertificate);
    }
    exit_open_ssl();
}

//===================Private methods======================================================

- (NSString *)resultForExtensionWithNID:(int)nid {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    NSString* result = AAGetX509ExtensionValue([self x509ExtensionWithNID: nid]);
    // trim newline characters
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"]];
    exit_open_ssl();
    return result;
}

- (NSString *)authorityKeyIdentifier {
    NSString *original = [self resultForExtensionWithNID:NID_authority_key_identifier];
    NSArray *comps = [original componentsSeparatedByString:@"\n"];
    return  comps.firstObject;
}

- (NSString *)nameFromX509AltName:(STACK_OF(GENERAL_NAME) *)altname type:(int)type {
    return [self nameFromX509AltName:altname type:type nid:NID_undef];
}

- (BOOL) verifyWithRootCertificate:(OpenSSLWrapper*)rootX509 {
    enter_open_ssl();
    if(self.x509Cert == nil || rootX509.x509Cert == nil) {
        exit_open_ssl();
        return NO;
    }
    EVP_PKEY *pkey = X509_get_pubkey(rootX509.x509Cert);
    BOOL success = (X509_verify(self.x509Cert, pkey) == 1);
    if (!success) {
        NSLog(@"%@", AAGetOpenSSLError());
    }

    if (pkey) {
        EVP_PKEY_free(pkey);
    }
    exit_open_ssl();
    return success;
}

- (NSArray<NSString *> *)entryFromX509Name:(X509_NAME *)name forKey:(NSString *)key {
    enter_open_ssl();
    NSMutableArray<NSString *> *entries = [NSMutableArray<NSString *> array];
    int entryCount = X509_NAME_entry_count(name);
    for (int i=0; i<entryCount; i++) {
        X509_NAME_ENTRY *entry = X509_NAME_get_entry(name, i);
        char buff[1024];
        ASN1_OBJECT *object = X509_NAME_ENTRY_get_object(entry);
        ASN1_STRING *value = X509_NAME_ENTRY_get_data(entry);
        OBJ_obj2txt(buff, 1024, object, 0);
        NSString *entryKey = [NSString stringWithUTF8String:buff];
        if ([entryKey isEqualToString:key]) {
            NSString *stringValue = [[NSString alloc] initWithData:[NSData dataWithBytes:value->data length:value->length]
                                                    encoding:NSUTF8StringEncoding];

            [entries addObject:stringValue];
        }
    }

    exit_open_ssl();
    return entries;
}


- (NSString *)nameFromX509AltName:(STACK_OF(GENERAL_NAME) *)altname type:(int)type nid:(int)nid {
    enter_open_ssl();
    NSString *name = nil;
    int entryCount = sk_GENERAL_NAME_num(altname);
    for (int i=0; i<entryCount; i++) {
        GENERAL_NAME *entry = sk_GENERAL_NAME_value(altname, i);
        if (entry->type == type) {
            // Currently boxer and PIV-D uses email, upn is used by PIV-D
            // There are other values available in GENERAL_NAME.
            // Handle other types, if any other data needed.
            const unsigned char *buff = NULL;
            switch (type) {
                case GEN_OTHERNAME:
                    if (OBJ_obj2nid(entry->d.otherName->type_id) == nid) {
                        buff = ASN1_STRING_get0_data(entry->d.otherName->
                                                value->value.asn1_string);
                        name = [NSString stringWithUTF8String:(char *)buff];
                    }
                    break;
                case GEN_EMAIL:
                    buff = ASN1_STRING_get0_data(entry->d.rfc822Name);
                    name = [NSString stringWithUTF8String:(char *)buff];
                    break;
                case GEN_DNS:
                    buff = ASN1_STRING_get0_data(entry->d.dNSName);
                    name = [NSString stringWithUTF8String:(char *)buff];
                    break;
                case GEN_URI:
                    buff = ASN1_STRING_get0_data(entry->d.uniformResourceIdentifier);
                    name = [NSString stringWithUTF8String:(char *)buff];
                    break;

                default:
                    break;
            }
            break;
        }
    }
    exit_open_ssl();
    return name;
}

- (NSString *)certificateUsePurpose {
    NSMutableString *str = [[NSMutableString alloc] initWithString:@""];
    if ([self hasExtendedUsage:SSL_Client]) {
        [str appendString:@"Authentication"];
    }
    if ([self canUseFor:DigitalSignature]) {
        [str appendString:@",Signing"];
    }


    if ([self canUseFor: DataEncipherment] || [self canUseFor:KeyEncipherment]) {
        [str appendString:@",Encryption"];
    }
    return str;
}

- (NSString*) getAttributeAtIndex:(NSUInteger)index {
    if (self.x509Cert == nil) {
        return nil;
    }
    enter_open_ssl();
    X509_NAME *name = X509_get_subject_name(self.x509Cert);
    X509_NAME_ENTRY *subjectEntry = X509_NAME_get_entry(name, (int)index);
    ASN1_STRING *value = X509_NAME_ENTRY_get_data(subjectEntry);
    if (value) {
        NSData *subjectData = [NSData dataWithBytes:value->data length:value->length];
        NSString* result = [[NSString alloc] initWithData:subjectData encoding:NSUTF8StringEncoding];
        exit_open_ssl();
        return result;
    }
    exit_open_ssl();
    return nil;

}
+ (uint8_t *)generateRandomBytes: (int)length {
    // Random Serial Number
    uint8_t *serial;
    serial = (uint8_t *)malloc(length + 1);
    memset(serial, 0x0, length + 1);

    RAND_bytes(serial, length);
     /* Making sure generated random bytes doesn't contain first bytes as Zero.
     if first byte is zero, We will keep generating new random bytes until get nonzero first byte
     */
    NSInteger firstByte = serial[0];
    while (length > 0 && firstByte == 0) {
        NSLog(@"First Byte: %ld",(long)firstByte);
        RAND_bytes(serial, length);
        firstByte = serial[0];
    }
    return serial;
}

- (NSData *)serializeRSAPublicKeyToDER:(RSA *)rsa {
    unsigned char *der = NULL;
    int derLength = i2d_RSA_PUBKEY(rsa, &der);

    if (derLength <= 0) {
        NSLog(@"Failed to serialize public key to DER");
        return nil;
    }
    NSData *derData = [NSData dataWithBytes:der length:derLength];
    OPENSSL_free(der);
    return derData;
}

+ (NSData *)publicKeyFromSecCertificate:(SecCertificateRef)certificate {
    if (certificate == NULL) {
        NSLog(@"Invalid certificate");
        return nil;
    }

    CFDataRef certData = SecCertificateCopyData(certificate);
    const void *certBytes = CFDataGetBytePtr((CFDataRef)certData);
    size_t certLen = CFDataGetLength(certData);

    X509 *x509 = d2i_X509(NULL, (const unsigned char **)&certBytes, (long)certLen);
    if (x509 == NULL) {
        NSLog(@"Failed to parse certificate");
        CFRelease(certData);
        return nil;
    }

    EVP_PKEY *pkey = X509_get_pubkey(x509);
    if (pkey == NULL) {
        NSLog(@"Failed to get public key from certificate");
        X509_free(x509);
        CFRelease(certData);
        return nil;
    }

    BIO *bio = BIO_new(BIO_s_mem());
    if (PEM_write_bio_PUBKEY(bio, pkey) != 1) {
        NSLog(@"Failed to write public key to BIO");
        BIO_free_all(bio);
        EVP_PKEY_free(pkey);
        X509_free(x509);
        CFRelease(certData);
        return nil;
    }

    char *pemData;
    long pemLen = BIO_get_mem_data(bio, &pemData);
    NSData *publicKeyData = [NSData dataWithBytesNoCopy:(void *)pemData length:pemLen freeWhenDone:NO];

    BIO_free_all(bio);
    EVP_PKEY_free(pkey);
    X509_free(x509);
    CFRelease(certData);

    return publicKeyData;
}

+ (NSData *)privateKeyFromSecKey:(SecKeyRef)privateKey {
    if (privateKey == NULL) {
        NSLog(@"Invalid private key");
        return nil;
    }

    CFDataRef keyData = SecKeyCopyExternalRepresentation(privateKey, NULL);
    const void *keyBytes = CFDataGetBytePtr((CFDataRef)keyData);
    size_t keyLen = CFDataGetLength(keyData);

    EVP_PKEY *pkey = d2i_PrivateKey(EVP_PKEY_id(NULL), NULL, (const unsigned char **)&keyBytes, (long)keyLen);
    if (pkey == NULL) {
        NSLog(@"Failed to parse private key");
        CFRelease(keyData);
        return nil;
    }

    BIO *bio = BIO_new(BIO_s_mem());
    if (PEM_write_bio_PrivateKey(bio, pkey, NULL, NULL, 0, NULL, NULL) != 1) {
        NSLog(@"Failed to write private key to BIO");
        BIO_free_all(bio);
        EVP_PKEY_free(pkey);
        CFRelease(keyData);
        return nil;
    }

    char *pemData;
    long pemLen = BIO_get_mem_data(bio, &pemData);
    NSData *privateKeyData = [NSData dataWithBytesNoCopy:(void *)pemData length:pemLen freeWhenDone:NO];

    BIO_free_all(bio);
    EVP_PKEY_free(pkey);
    CFRelease(keyData);

    return privateKeyData;
}


- (EVP_PKEY *)extractPublicKeyFromCertificate:(SecCertificateRef)certificate {
    NSData *certificateData = (NSData *)CFBridgingRelease(SecCertificateCopyData(certificate));
    const unsigned char *bytes = [certificateData bytes];
    X509 *x509 = d2i_X509(NULL, &bytes, certificateData.length);

    EVP_PKEY *publicKey = X509_get_pubkey(x509);

    if (publicKey) {
        BIO *bio = BIO_new(BIO_s_mem());
        PEM_write_bio_PUBKEY(bio, publicKey);

        char *pemKey = NULL;
        long pemLen = BIO_get_mem_data(bio, &pemKey);
        NSData *publicKeyData = [NSData dataWithBytes:pemKey length: pemLen];
        NSLog(@"Key data: %lu",(unsigned long)publicKeyData.length);
        /*
        NSString *publicKeyString = [[NSString alloc] initWithBytes:pemKey
                                                             length:pemLen
                                                           encoding:NSUTF8StringEncoding];
        NSLog(@"Public Key:\n%@", publicKeyString); */

        BIO_free(bio);
        EVP_PKEY_free(publicKey);
    } else {
        NSLog(@"Failed to extract public key.");
    }

    X509_free(x509);
    return publicKey;
}

- (EVP_PKEY *)extractPrivateKeyFromPKCS12:(NSData *)pkcs12Data
                           password:(NSString *)password {
    const unsigned char *bytes = [pkcs12Data bytes];
    PKCS12 *p12 = d2i_PKCS12(NULL, &bytes, pkcs12Data.length);

    EVP_PKEY *privateKey = NULL;
    X509 *cert = NULL;
    STACK_OF(X509) *ca = NULL;
    if (PKCS12_parse(p12, [password cStringUsingEncoding:NSUTF8StringEncoding], &privateKey, &cert, &ca)) {
        BIO *bio = BIO_new(BIO_s_mem());
        PEM_write_bio_PrivateKey(bio, privateKey, NULL, NULL, 0, NULL, NULL);

        char *pemKey = NULL;
        // Print key as String
        long pemLen = BIO_get_mem_data(bio, &pemKey);
        NSData *privateKeyData = [NSData dataWithBytes:pemKey length:pemLen];
        NSLog(@"Key data: %lu",(unsigned long)privateKeyData.length);

//        NSString *privateKeyString = [[NSString alloc] initWithBytes:pemKey length:pemLen encoding:NSUTF8StringEncoding];
//        NSLog(@"Private Key:\n%@", privateKeyString);

        BIO_free(bio);
        EVP_PKEY_free(privateKey);
    } else {
        NSLog(@"Failed to extract private key.");
    }

    PKCS12_free(p12);
    return privateKey ;
}

- (NSData *)convertP12DataToPKCS12Data:(NSData *)p12Data
                               password:(NSString *)password {
    const unsigned char *bytes = [p12Data bytes];
    PKCS12 *p12 = NULL;
    NSData *pkcs12Data = NULL;
    // Parse the p12 data to create a PKCS12 structure
    p12 = d2i_PKCS12(NULL, &bytes, p12Data.length);

    if (!p12) {
        NSLog(@"Failed to convert p12 data to PKCS12 structure.");
        return pkcs12Data;
    }

    EVP_PKEY *pkey = NULL;
    X509 *cert = NULL;
    STACK_OF(X509) *ca = NULL;

    // Parse the PKCS12 structure to extract the private key, certificate, and CA certificates
    if (PKCS12_parse(p12, [password cStringUsingEncoding:NSUTF8StringEncoding], &pkey, &cert, &ca)) {
        NSLog(@"Successfully parsed PKCS12 structure.");

        if (pkey) {
            BIO *bio = BIO_new(BIO_s_mem());
            PEM_write_bio_PrivateKey(bio, pkey, NULL, NULL, 0, NULL, NULL);

            char *pemKey = NULL;
            long pemLen = BIO_get_mem_data(bio, &pemKey);

//            NSString *privateKeyString = [[NSString alloc] initWithBytes:pemKey length:pemLen encoding:NSUTF8StringEncoding];
//            NSLog(@"Private Key:\n%@", privateKeyString);

            BIO_free(bio);
            EVP_PKEY_free(pkey);
        }

        if (cert) {
            BIO *bio = BIO_new(BIO_s_mem());
            PEM_write_bio_X509(bio, cert);

            char *pemCert = NULL;
            long pemLen = BIO_get_mem_data(bio, &pemCert);
            // Wrap the encrypted message in an NSData object
            pkcs12Data = [NSData dataWithBytes:pemCert length:pemLen];
//            NSString *certificateString = [[NSString alloc] initWithBytes:pemCert length:pemLen encoding:NSUTF8StringEncoding];
//            NSLog(@"Certificate:\n%@", certificateString);

            BIO_free(bio);
            X509_free(cert);
        }

        if (ca) {
            // Handle CA certificates if needed
            sk_X509_pop_free(ca, X509_free);
        }
    } else {
        NSLog(@"Failed to parse PKCS12 structure.");
    }
    PKCS12_free(p12);
    return pkcs12Data;
}

//===================Private methods======================================================


@end
