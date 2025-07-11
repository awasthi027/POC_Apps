# This sample application I have created to understand working of iOS extension, How to get from extension? How to debug extension etc.

# 1. Written UI test case Launching share extension from the  safari 
# 2. Written UI test case present ViewController on extension
# 3. We can design UI element on share extension
# 4. How to access framework feature flag code from the extension
# 5. How feature flag works in Podspec
# 6. How we can access default subspecs
# 7. How to debug extension -> Put break point in extension class ->Run extension target -> Launch Safari-> Launch Extension ->Break point will hit 
# 8. How to log import os.log    let logger = OSLog(subsystem: "ashi.com.com.ExtensionPOC.ShareExt", category: "extension") and log     os_log("Extension started processing", log: logger, type: .info)
# 9. The behavior you're seeing is expected due to how Apple's Unified Logging system filters logs by default. Here's why you're not seeing .info logs and how to make them visible     Console.app hides .info logs by default (only shows .default, .error, .fault) This is an intentional privacy/performance optimization by Apple
# 10. Sometime Mac console app doen't get log due synchonus issue, Quit MAC console app and relaunch, it will print the log.
# 11. You can get log ter command also:  log show --predicate 'subsystem == "ashi.com.com.ExtensionPOC"' --last 10m --info    How I tried getting log via command it was not showing on My Machine
# 12. Sometime we install build in iPhone and without xCode we are trying to get log, It's not possible. If app using cocoalumberJack for logging they internally printing debug, error, fault log in OS log. We can simply connect device with MAC and Open Mac Console and filter log with category or message or bundle id 
# 13. Just type you filter message -> Enter -> Select filter type example: Subsystem, Category etc ->Enter 
# 14. If we know any message directly we can search or search by deferent params like params category, subsystem type etc
# Debug log always comes in MAC console app, other log fault etc some time not comes. may be syncing issue.
# 15. Simulator Run this command and get live log terminal for extension Run extenion with safari 

sudo log stream \
--style syslog \
--predicate 'subsystem == "ashi.com.com.ExtensionPOC.ShareExt"' \
--level debug \
--timeout 30s \
--source

# 16. Simulator Get app log Run This command and then run app 

sudo log stream \
--style syslog \
--predicate 'subsystem == "ashi.com.com.ExtensionPOC"' \
--level debug \
--timeout 30s \
--source
