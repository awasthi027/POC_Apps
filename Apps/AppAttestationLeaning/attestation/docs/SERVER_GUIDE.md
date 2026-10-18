# Apple App Attest – Server Guide (Spring Boot)

A learning sample of the **server side** of Apple App Attest. The goal: only a
genuine, unmodified copy of your iOS app, on a real Apple device, can call the
protected endpoints. The iOS client is out of scope except for the data it sends.

> Learning scope: registered keys and nonces are kept **in memory**. A server
> restart clears them, and the app must register a new key afterwards.

---

## 1. Concepts

| Term | Meaning |
|---|---|
| **Key** | EC P-256 key pair created in the device's Secure Enclave. The private key never leaves the device. |
| **keyId** | `Base64(SHA256(uncompressed public key))`. Apple returns it when the key is generated. |
| **Attestation** | One-time proof, signed by Apple, that the key lives in a genuine app on a genuine device. Used for **registration**. |
| **Assertion** | Per-request signature made with that key. Used for **protected calls**. |
| **clientDataHash** | A hash the server defines and the client signs. It binds the signature to a specific challenge or request. |
| **rpIdHash** | `SHA256(teamId.bundleId)`. Proves which app produced the data. |
| **Counter** | Increases with each assertion. Used to block replays. |

Two phases:

```
Phase 1  Register   (once per key)   POST /attestation/register   -> verify Apple attestation, store public key
Phase 2  Protected  (every request)  GET  /protected/profile      -> verify assertion (signature) with stored key
         Protected                   POST /protected/echo
```

---

## 2. Project layout

```
config/            AttestationBeanConfig      wires beans, builds appId = teamId.bundleId
application/       AttestationService         business rules (register + verify request)
application/port/  AttestationCryptoPort ...  interfaces (hexagonal style)
infrastructure/
  crypto/          AttestationCrypto          CBOR, X.509, nonce, ECDSA
  store/           InMemoryRegisteredKeyRepository, InMemoryNonceStore
  http/            AttestationController + request/response records
domain/            RegisteredKey, ProtectedRequest, VerificationResult
```

Configuration (`application.properties`):

```properties
app.attestation.team-id=9VL795556B
app.attestation.bundle-id=ashi.com.newLearning.ai-concept-learning.AppAttestationLeaning
app.attestation.allowed-clock-skew-ms=120000   # timestamp tolerance (2 min)
app.attestation.nonce-retention-ms=600000      # how long nonces are remembered (10 min)
```

The expected app identity is built once at startup:

```java
// AttestationBeanConfig
String appId = teamId + "." + bundleId;

// AttestationService constructor
this.expectedAppIdHash = crypto.sha256(appId.getBytes(StandardCharsets.UTF_8));
```

---

## 3. Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | none | liveness |
| POST | `/attestation/register` | Apple attestation | register a key |
| GET | `/protected/profile` | assertion headers | sample protected GET |
| POST | `/protected/echo` | assertion headers | sample protected POST (with body) |

Register request body (`RegisterKeyRequest`):

```json
{
  "keyId": "<base64 keyId>",
  "challenge": "<base64url challenge, optional>",
  "clientDataHash": "<base64url SHA256(challenge)>",
  "attestationObject": "<base64url CBOR from Apple>"
}
```

Protected request headers:

```
X-AppAttest-Key-Id
X-AppAttest-Assertion          base64url CBOR from generateAssertion
X-AppAttest-Client-Data-Hash   base64url SHA256(binding string, see 5.2)
X-AppAttest-Timestamp          epoch millis
X-AppAttest-Nonce              unique per request
```

---

## 4. Phase 1 – Registration

### 4.1 Controller

```java
@PostMapping("/attestation/register")
public ResponseEntity<?> registerKey(@RequestBody(required = false) RegisterKeyRequest request) {
    ...
    try {
        attestationService.registerKey(keyId, challenge, clientDataHash, attestationObject);
        return ResponseEntity.status(HttpStatus.CREATED).body(new RegisterKeyResponse("registered", keyId));
    } catch (GeneralSecurityException e) {
        return ResponseEntity.badRequest()
                .body(new AttestationErrorResponse("Invalid App Attest payload: " + e.getMessage()));
    }
}
```

Any verification failure becomes a `400` with a reason.

### 4.2 Service orchestration

```java
public void registerKey(String keyId, String challengeB64, String clientDataHashB64,
                        String attestationObjectB64) throws GeneralSecurityException {
    String normalizedKeyId = normalizeKeyId(keyId);
    byte[] clientDataHash = crypto.decodeBase64Url(clientDataHashB64);

    if (!isBlank(challengeB64)) {                       // challenge binding
        byte[] challenge = crypto.decodeBase64Url(challengeB64);
        if (!crypto.constantTimeEquals(crypto.sha256(challenge), clientDataHash)) {
            throw new GeneralSecurityException("clientDataHash does not match challenge");
        }
    }

    ParsedAttestation parsed = crypto.parseAndVerifyAttestationObject(
            attestationObjectB64, clientDataHash, keyId);

    if (!crypto.constantTimeEquals(parsed.rpIdHash(), expectedAppIdHash)) {   // right app?
        throw new GeneralSecurityException("Attestation rpIdHash does not match app identifier");
    }

    RegisteredKey registeredKey = new RegisteredKey(parsed.publicKey(), parsed.rpIdHash());
    registeredKey.assertionCounter(parsed.signCount());
    keyRepository.save(normalizedKeyId, registeredKey);
}
```

### 4.3 Attestation verification steps (`AttestationCrypto`)

Apple's attestation object is CBOR:

```
{ fmt: "apple-appattest",
  attStmt: { x5c: [leafCert, intermediateCert], receipt: ... },
  authData: <bytes> }
```

**Step 1 – decode and check format**

```java
Map<Object, Object> attestation = CBOR_MAPPER.readValue(rawAttestationObject, new TypeReference<>() {});
if (!"apple-appattest".equals(asString(attestation.get("fmt")))) {
    throw new GeneralSecurityException("Unsupported attestation format");
}
```

**Step 2 – authData must contain attested credential data** (flag bit `0x40`)

```java
int flags = authData[FLAG_OFFSET] & 0xFF;            // byte 32
if ((flags & FLAG_ATTESTED_CREDENTIAL_DATA) == 0) {
    throw new GeneralSecurityException("Attested credential data flag is not set");
}
```

authData layout used by the code:

```
0..31   rpIdHash (32)
32      flags
33..36  counter (uint32, big endian)
37..52  aaguid (16)
53..54  credentialId length
55..    credentialId, then COSE public key (CBOR)
```

**Step 3 – validate the certificate chain to Apple's root CA**

```java
leaf.checkValidity();
intermediate.checkValidity();
leaf.verify(intermediate.getPublicKey());

CertPath certPath = CertificateFactory.getInstance("X.509").generateCertPath(List.of(leaf, intermediate));
PKIXParameters pkix = new PKIXParameters(Set.of(new TrustAnchor(appleAppAttestationRootCA(), null)));
pkix.setRevocationEnabled(false);
CertPathValidator.getInstance("PKIX").validate(certPath, pkix);
```

The Apple App Attestation Root CA is embedded as a PEM constant in the class.
This is what makes a fake attestation impossible: the chain must end at Apple.

**Step 4 – nonce check.** Apple puts `SHA256(authData || clientDataHash)` in a
certificate extension (OID `1.2.840.113635.100.8.2`). The server recomputes it
and compares:

```java
byte[] expectedNonce = sha256(concat(authData, clientDataHash));
byte[] nonceFromCert = extractNonceFromCertificate(leaf);
if (!constantTimeEquals(expectedNonce, nonceFromCert)) {
    throw new GeneralSecurityException("Certificate nonce does not match authData/clientDataHash");
}
```

This ties the attestation to your `clientDataHash`, so it can't be reused with another challenge.

**Step 5 – read the public key from the COSE key and check the keyId**

```java
byte[] x = coseCoordinate(coseKey, -2);   // COSE label -2 = x
byte[] y = coseCoordinate(coseKey, -3);   // COSE label -3 = y
```

```java
byte[] derivedKeyId  = sha256(uncompressedPublicKey);        // 0x04 || x || y
byte[] providedKeyId = decodeBase64Flexible(expectedKeyId);  // accepts Base64 and Base64URL
if (!constantTimeEquals(derivedKeyId, providedKeyId)) {
    throw new GeneralSecurityException("keyId does not match attested public key");
}
```

Notes learned while building:
- COSE labels come back from the CBOR mapper as strings (`"-2"`), so `isCoseLabel` accepts numeric and string labels.
- The iOS `keyId` is standard Base64 (`+`, `/`, `=`), not Base64URL, so key ids are compared as **bytes**.

**Step 6 – build the Java public key**

```java
ECParameterSpec ecParameters = ... "secp256r1" ...;
ECPoint point = new ECPoint(new BigInteger(1, xCoord), new BigInteger(1, yCoord));
PublicKey publicKey = KeyFactory.getInstance("EC").generatePublic(new ECPublicKeySpec(point, ecParameters));
```

**Step 7 – the service then checks `rpIdHash`** against `SHA256(teamId.bundleId)`
(shown in 4.2), and saves the key together with the starting counter.

### 4.4 keyId normalisation (storage side)

The same key can arrive as Base64 or Base64URL. The service stores and looks up by one canonical form:

```java
private String normalizeKeyId(String keyId) {
    byte[] rawKeyId = decodeKeyIdFlexible(keyId);
    return crypto.base64UrlEncode(rawKeyId);     // Base64URL, no padding
}
```

Without this you get `Unknown keyId` even for a registered key.

---

## 5. Phase 2 – Protected requests

### 5.1 Controller

Both protected endpoints build a `ProtectedRequest` and call the service.
The GET version has an empty body:

```java
@GetMapping("/protected/profile")
public ResponseEntity<?> protectedProfile(@RequestHeader(...) String keyId, ..., HttpServletRequest httpRequest) {
    ProtectedRequest protectedRequest = new ProtectedRequest(
            httpRequest.getMethod(), httpRequest.getRequestURI(), new byte[0],
            trim(keyId), trim(assertionObjectB64), trim(clientDataHashB64),
            trim(timestampRaw), trim(nonce));

    VerificationResult result = attestationService.verifyProtectedRequest(protectedRequest);
    if (!result.valid()) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new AttestationErrorResponse(result.message()));
    }
    return ResponseEntity.ok(Map.of("status", "accepted", ...));
}
```

Failure returns `401` with the reason. Only the URI path is bound (no query string).

### 5.2 What the client must hash (`canonicalBinding`)

```java
String bodyHashB64 = base64Url(SHA256(body));
return String.join("\n",
        method.toUpperCase(),
        path,
        bodyHashB64,
        String.valueOf(timestamp),
        nonce,
        keyId);
```

`clientDataHash = SHA256(thatString)`. The client signs this hash through
`generateAssertion`. The server **rebuilds the string from the real request**
and never trusts the client's hash by itself.

### 5.3 Verification pipeline (`verifyProtectedRequest`)

```java
// 1. headers present
// 2. key known
RegisteredKey registeredKey = keyRepository.findByKeyId(normalizedKeyId);
if (registeredKey == null) return VerificationResult.fail("Unknown keyId");

// 3. freshness
if (Math.abs(now - timestamp) > allowedClockSkewMs)
    return VerificationResult.fail("Request freshness check failed");

// 4. replay protection
if (nonceStore.isReplay(normalizedKeyId, request.nonce(), now))
    return VerificationResult.fail("Nonce replay detected");

// 5. request binding
byte[] expectedClientDataHash = crypto.sha256(canonicalBinding(...).getBytes(UTF_8));
if (!crypto.constantTimeEquals(providedClientDataHash, expectedClientDataHash))
    return VerificationResult.fail("Request binding check failed");

// 6. app identity
AttestationCryptoPort.ParsedAssertion parsedAssertion = crypto.parseAssertionObject(request.assertionObjectB64());
if (!crypto.constantTimeEquals(parsedAssertion.rpIdHash(), registeredKey.rpIdHash()))
    return VerificationResult.fail("Assertion rpIdHash does not match registered app");

// 7. signature
boolean ok = crypto.verifyAssertionSignature(registeredKey.publicKey(),
        parsedAssertion.authenticatorData(), expectedClientDataHash, parsedAssertion.signature());
if (!ok) return VerificationResult.fail("Assertion signature verification failed");

// 8. counter
synchronized (registeredKey.lock()) {
    if (parsedAssertion.signCount() <= registeredKey.assertionCounter())
        return VerificationResult.fail("Out-of-order or replayed assertion counter");
    registeredKey.assertionCounter(parsedAssertion.signCount());
}
return VerificationResult.pass();
```

| # | Check | Stops |
|---|---|---|
| 2 | key was registered | unregistered or fake clients |
| 3 | timestamp within skew | old captured requests |
| 4 | nonce not seen | replay of the same request |
| 5 | hash equals server recomputation | signature reuse on a different request/body/path |
| 6 | rpIdHash matches | assertions from another app |
| 7 | ECDSA signature | forged requests (no private key) |
| 8 | counter increases | replay of older assertions |

### 5.4 Assertion object

CBOR `{ signature, authenticatorData }`:

```java
byte[] authenticatorData = asByteArray(assertion.get("authenticatorData"));
byte[] signature         = asByteArray(assertion.get("signature"));
// rpIdHash = first 32 bytes, counter = bytes 33..36 of authenticatorData
```

### 5.5 Signature verification (the key detail)

Apple's rule: `nonce = SHA256(authenticatorData || clientDataHash)`, and the
signature is ECDSA over that nonce.

```java
byte[] nonce = sha256(concat(authData, clientDataHash));
Signature verifier = Signature.getInstance("SHA256withECDSA");
verifier.initVerify(publicKey);
verifier.update(nonce);
try {
    return verifier.verify(signature);          // DER-encoded signature
} catch (SignatureException e) {
    return false;
}
```

Skipping the first hashing step makes every assertion fail with
`Assertion signature verification failed`. That was the bug during development.
The verification stays strict: one payload form, one signature encoding.

### 5.6 Replay store

```java
public boolean isReplay(String keyId, String nonce, long now) {
    evictExpired(now);
    Long previous = nonceCache.putIfAbsent(keyId + ":" + nonce, now);   // atomic
    return previous != null;
}
```

Nonces are kept for `nonce-retention-ms` (10 min), longer than the allowed clock
skew (2 min), so any request still inside the freshness window is covered.

---

## 6. Testing the flow

```bash
# Rejected: no attestation headers
curl -i http://localhost:8080/protected/profile
# 401 {"error":"Missing required attestation headers"}

# Accepted: values must come from the iOS app (single use)
curl -i http://localhost:8080/protected/profile \
  -H "X-AppAttest-Key-Id: <keyId>" \
  -H "X-AppAttest-Assertion: <base64url assertion>" \
  -H "X-AppAttest-Client-Data-Hash: <base64url sha256 binding>" \
  -H "X-AppAttest-Timestamp: <epoch ms>" \
  -H "X-AppAttest-Nonce: <unique nonce>"
```

Run: `mvn spring-boot:run` (needs JDK 25 as configured in `pom.xml`).

---

## 7. Error reference

| Message | Likely cause |
|---|---|
| `COSE key missing coordinate label -2` | COSE labels read as strings; handled by `isCoseLabel` |
| `keyId does not match attested public key` | keyId compared as text with different Base64 alphabets; compare bytes |
| `Certificate nonce does not match ...` | client used a different `clientDataHash` than the one sent to the server |
| `Attestation rpIdHash does not match app identifier` | wrong `team-id` or `bundle-id` in properties |
| `Unknown keyId` | server restarted (memory store) or key never registered |
| `Request binding check failed` | client hashed a different method/path/body/timestamp/nonce/keyId than the server |
| `Assertion signature verification failed` | missing nonce hash step, or client signed a different `clientDataHash` |
| `Nonce replay detected` | same nonce reused |
| `Out-of-order or replayed assertion counter` | old assertion resent or counters out of sync |

---

## 8. Security properties and limits

What this server gives you:
- Only requests signed by a Secure Enclave key attested by Apple for **your** app ID are accepted.
- Requests are bound to method, path, body, time and nonce, so they cannot be altered or replayed.

What it does not give you:
- Proof of a legitimate **user**. Combine it with real authentication.
- Protection on a jailbroken device that runs the real app. Add rate limits, per-user quotas, anomaly detection and revocation.

Known gaps in this sample (acceptable for learning, fix before production):
1. **In-memory storage.** Keys and nonces are lost on restart.
2. **Challenge is optional at registration.** Production should issue a single-use server challenge and require it.
3. **No environment check.** Production should read the `aaguid` (`appattest` vs `appattestdevelop`) so dev builds can't register.
4. **No rate limiting or key revocation.**
5. **Receipt not processed.** Apple's `receipt` could feed the risk metric.
6. **Revocation checking** on the certificate chain is disabled (`setRevocationEnabled(false)`).
