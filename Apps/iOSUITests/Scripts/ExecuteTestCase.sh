
#echo "Deleting existing source code folder"
#
#rm -r POC_Apps
#
#echo "Deleted existing directory"

echo "---- Closing Xcode ----"
killall Xcode

# Not needed
#echo "---- Closing Simulator ----"
#killall "Simulator" || true
#
#echo "---- Available simulators ----"
#xcrun simctl list devices --json

#echo "---- Removing derived data ----"
#
#rm -r ~/Library/Developer/Xcode/DerivedData

echo "Running clone commands"

git clone https://github.com/awasthi027/POC_Apps.git

echo "Finished cloning..."

cd POC_Apps/Apps/iOSUITests

echo "Now at path iOSUITests"

echo "---- De-integrating pods ----"
pod deintegrate

echo "---- Installing pods ----"

pod install

echo "---- Opening Xcode ----"

open /Applications/Xcode.app

echo "---- Opening Project ----"
open UITestPOC.xcworkspace


echo "---- Cleaning Build ----"
xcodebuild -workspace UITestPOC.xcworkspace -scheme UITestPOC -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0.1' clean

echo "---- Building Project ----"

xcodebuild -workspace UITestPOC.xcworkspace -scheme UITestPOC -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0.1' build

echo "---- Running test UT and Unit test cases ----"
xcodebuild -workspace UITestPOC.xcworkspace -scheme UITestPOC -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0.1' test

