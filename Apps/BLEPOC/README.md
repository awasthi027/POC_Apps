# BLE Sample app


### BLE Configueration ###

Make sure these things are enable for testing, Otherwise BLE device will function as expected.

Enable background capability

Select Target -> Signing & Capabilities -> Background Mode -> Uses BlueTooth LE Accessorey -> Checked

Add BLE Instruction Key In Plist

Privacy - Bluetooth Always Usage Description = We need Bluetooth access to act as a peripheral and communicate with other devices. 


Maximum data with BLE is 20 bytes at a time, If you send more than that it will be chunked into multiple packets
Maximum data data + Header example Maximum data is 20 bytes and 3 Bytes header so total 23 bytes

Again its depends on the device how much data it can handle at a time.

Using iPhone 14 as BLE can tranfer maximum 512 limit.

Tested Source code working on Two device, Commmunication work as expected.
