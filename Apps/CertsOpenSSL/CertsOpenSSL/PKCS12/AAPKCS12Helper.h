//
//  AAPKCS12Helper1.h
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 02/02/25.
//

#import <Foundation/Foundation.h>
#import <openssl/evp.h>
#import <openssl/pem.h>
#import <openssl/rsa.h>
#import <openssl/sha.h>

NSData *signMessageWithPrivateKey(EVP_PKEY *privKey, NSData *message);
BOOL verifySignatureWithPublicKey(EVP_PKEY *pubKey, NSData *message, NSData *signature);




/*
 A signed message in cryptography refers to a message that has been given a digital signature. This signature verifies the authenticity and integrity of the message, ensuring that it has not been tampered with and that it indeed comes from the purported sender.
 How It Works

     Hashing:

         First, a hash function is applied to the original message to create a message digest. This digest is a fixed-size, unique representation of the message content.

     Signing:

         The sender then encrypts this digest with their private key. This encrypted digest is the digital signature.

     Sending:

         The original message, along with the digital signature, is sent to the recipient.

     Verification:

         The recipient decrypts the digital signature using the sender's public key, retrieving the message digest.

         The recipient then hashes the received message with the same hash function and compares this new digest to the decrypted one.

         If they match, the message is verified as authentic and untampered; otherwise, it indicates potential tampering or a forgery attempt.

 Use Cases

     Email Security:

         Digital signatures are widely used in email communications to ensure that emails are not altered in transit and truly originate from the claimed sender.

     Software Distribution:

         When software developers release their applications or updates, they often sign these files. Users can verify the signatures to ensure they are installing genuine, unaltered software.

     Financial Transactions:

         In the financial sector, digital signatures are used to authenticate transactions, ensuring that they are authorized by the legitimate account holders.

     Document Signing:

         Digital signatures are used for signing documents digitally, providing a legal and tamper-evident way of approving or agreeing to the content within.

 Example

 Let’s say Alice wants to send a signed message to Bob. The process would look like this:

     Alice: Hashes the message to create a digest.

     Alice: Encrypts the digest with her private key to create the digital signature.

     Alice: Sends the message and the digital signature to Bob.

     Bob: Decrypts the digital signature with Alice’s public key to retrieve the digest.

     Bob: Hashes the received message to create a new digest.

     Bob: Compares the two digests. If they match, the message is verified; if not, it indicates an issue.

 Digital signatures are essential in ensuring data integrity and authenticity in various applications, contributing to secure communications and transactions. If you'd like more details or have any specific questions, feel free to ask!
 */
