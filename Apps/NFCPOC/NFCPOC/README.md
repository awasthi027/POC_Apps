# Some important documentation about NFC tag reading and writing with commands 

**Step 1.

1. Enable NFC capability in your provisiong profile and project 

**2. Make entry info plist 

Key: Value 
Privacy - NFC Scan Usage Description : NFC tag to read NDEF messages into the application

**3. If reading iOS  ISO7816 or Any Type make entry in plist

ISO7816 application identifiers for NFC Tag Reader Session 
ISO7816 application identifiers for NFC Tag Reader Session : [A000000527471117]

** 4 Start session and read tag type ISO7816

** 5 Connect Tag 

** 6 Execute command 

** 7 Selected App




** Medium Link 

** 1. How form packet and execute commands 

https://hpkaushik121.medium.com/understanding-apdu-commands-emv-transaction-flow-part-2-d4e8df07eec

** 2.Complete list of APDU responses code and explanation 

https://www.eftlab.com/knowledge-base/complete-list-of-apdu-responses
