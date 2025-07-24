# 1. At the start of the SDK, we can create an application data store object.

# 2. The application data store can support various types of data storage, such as Plist store, file store, SQL store, KeyChain store, and more.

# 3. These storage options can be either secure or unsecured. For example, a store can be secured with a dynamic key or any other type of key.

# 4.When we create an instance of the ApplicationDataStore, it can load unsecured data stores and secure them with a dynamic key or another type of key. However, the master data will remain locked until we obtain the master key.

# 5. If the store is secure, like the master store, it will be locked with a key. This key can be generated using a username/password, passcode, random key, or a session with random data.

# 6. The master key can be generated randomly and encrypted based on the required key types, such as username/password, passcode, random key, session, random key, or biometrics, and then saved in the store.

# 7. To decrypt the key, we need one derived key from the authentication process, which can be the username/password, passcode, random key, session key, or stored under biometrics or device PIN.

# 8. Once we obtain the original master key by decrypting it using one of the available methods, we can unlock the data store with the master key.

# 9. The encrypted master key can be stored in a hardware secure space.

# 10. For forgotten passcode recovery, the master key is encrypted with an escrow key that is randomly generated. This encrypted key can be stored in the cloud. When the user authenticates correctly with their username and password, the server can provide the escrow key. By using the escrow key, we can retrieve the master key.

# 11. If Folio Settings are enabled in customer settings, we can create an application recovery key and save it. When a user switches accounts and we need to share data, we can decrypt the data using the recovery key. This use case is applicable.



