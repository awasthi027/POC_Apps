# Table of Content

** Important Notes for developer **
1. Enabled Keychain group in consumber App "com.apple.token" This is madatory to get CTK certificates
2. Enable Face id by adding key in CTK extesion app: (forKeychain access via biomatrix )
3. Keychain sharing should be enabled  (Extension can access keychain data)
4. NFC scan key should be present in CTK extesion app and enable in Signing & Capabilities(ForYubiKey)
5. NFC Tag reading should enabled in CTK extesion app and check Tag(ForYubiKey)
** Safari can use certificate installed in Keychain **

Safari and ASWebAuthenticationSession both can access certificate from CTK 
Certificate app has to write certificate in CTK and create a Persistent Token Kit extension.
When user want perform crypto graphic operation example: Webside authentication
When user make request https and tls 1.3 request via safari or ASWebAuthenticationSession Persistent Token Kit get called.
It read certificate from the CTK and complete the operation 

** How Persistent Token kit will complete the operation ** 

Certificate app can write public part of certificate and certificate payload contain p12 data and password CTK.
When user want to perform crypto graphic operation Via safari or ASWebAuthenticationSession Persistent token Kit extension get called.
It give payload which contain certificate p12 data and password.
Extension can get private key and perform operation.

** Why are we writing complete payload which contain certificate data and password **
When we perform operation, without user intervention operation.
If user intervention We can take Write private in Shared keychain read by extession and app.
We can write only certificate private key in share keychain which can read by the Persistent token Kit extension and app
Create has from public part and make it as key, againt that hashkey we can write private key under device biomatrix or passcode
that certificate hash we can write with payload as certificate key configuration, So when Token driver called, We can get private from shared keychain againt that certhash.

** How will you handle if crypto operation only can perform App confirm, Unlock the extension app and then only you can perform operation **
Write crypto graphic request in shared user group -> extension invoke app with local notification -> extnesion Wait for 60 seconds so user  can click notification to launch app 
in while loop extension keep cheking in each 5 seconds from shared user group key to know whether user launch the app and completed the operation or not If yes complete waiting time and 
read result from shared user group and complete operation.

** How user can authenticate via Yubikey certificate **
Certificate app read public certificate part from the Yubikey with help Yubikey SDK and write in CTK.
User launch safari -> Enter Authenticate URL -> Persist token kit called -> Persist token called knows its request for YubiKey certificate.
Persist token kit ->  Persist token kit write pperation request in shared User Group and Create Local notification to launch the app -> Now Persist token kit add timer 
to wait 60 seconds and check every 5 seocnds whether user completed operation or not. If user click on notification complete operation before 60 seconds. It will read operation data from 
shared group and Persist token kit return to requester.
App will give authentication call to YubiKey SDK and SDK Will ask to user insert YoubKey, It sign the data and write in shared group.







