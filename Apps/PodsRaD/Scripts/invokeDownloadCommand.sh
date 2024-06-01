echo "\nStarting download of latest sdk frameworks..."

RED='\033[0;31m'
NC='\033[0m' # No Color

DESTINATION_DIRECTORY="$1"
DOWNLOAD_URL="$2"
CURRENT_BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD | tr / -)"
XCODE_VERSION="$(xcodebuild -version | tr " " - | tr "\n" "$" | cut -d "$" -f 1)"
# If xcode version is composed of three digits including the patch number, cut the patch number off as we only label our ThirdPartyRelease Frameworks with major and minor version numbers
res="${XCODE_VERSION//[^.]}"
if [ "${#res}" != "1" ]; then
  echo "Detected currently used xcode command line tools version to be: (${XCODE_VERSION})"
  XCODE_VERSION=${XCODE_VERSION%??}
  echo "Trimming last version digit from xcode version as we only track major and minor version numbers for our release frameworks. Trimmed to: (${XCODE_VERSION})"
fi

# print variables
echo "\n-----Variables------"
echo "CURRENT_BRANCH_NAME = $CURRENT_BRANCH_NAME"
echo "DESTINATION_DIRECTORY = $DESTINATION_DIRECTORY"
echo "XCODE_VERSION = $XCODE_VERSION"
echo "--------------------\n"

# check that the variables are valid
if [ -z "$DESTINATION_DIRECTORY" ]; then
  echo "Error: destination directory is nil exiting with error..."
  exit 1
fi

if [ -z "$CURRENT_BRANCH_NAME" ]; then
  echo "Error: current branch name is nil exiting with error..."
  exit 1
fi

# remove any pre-existing frameworks
echo "Removing any pre-existing AirWatchSDK frameworks..."
rm -rf "$DESTINATION_DIRECTORY"

# make directory for thirdparty frameworks
mkdir -p "$DESTINATION_DIRECTORY"
echo "Making directory if does not already exist $DESTINATION_DIRECTORY"

# execute download command https://www.clickdimensions.com/links/TestPDFfile.pdf
DOWNLOAD_COMMAND="$DOWNLOAD_URL --output $DESTINATION_DIRECTORY/AWSDK.pdf"
echo "DOWNLOAD_COMMAND = curl $DOWNLOAD_COMMAND"
curl -f $DOWNLOAD_COMMAND

zip -r "$DESTINATION_DIRECTORY/AWSDK.zip" "$DESTINATION_DIRECTORY"

#check that download succeeded
EXPECTED_FILENAME="$DESTINATION_DIRECTORY/AWSDK.zip"
echo "\nChecking for the existance of $EXPECTED_FILENAME ..."
if [ -e "$EXPECTED_FILENAME" ]; then
  echo "Download succeeded"
else
  echo "${RED}!!! ERROR !!! Download failed. There are no pre-compiled sdk frameworks on artifactory matching both the current branch name: ($CURRENT_BRANCH_NAME) and the current xcode version: ${XCODE_VERSION}.${NC}"
  echo "${RED}!!! ERROR !!! You will need to manually add pre-compiled sdk frameworks to the third party target if you wish to compile the target.\n${NC}"
  echo "${RED}!!! ERROR !!! This does not effect the other targets.\n${NC}"
  exit 1
fi

# unzip frameworks
echo "Unzipping frameworks into: ($DESTINATION_DIRECTORY)..."
unzip "$DESTINATION_DIRECTORY/AWSDK.zip" -d "$DESTINATION_DIRECTORY/" 2>&1 > /dev/null

# clean up directory
echo "Cleaning up directory..."
rm -f "$DESTINATION_DIRECTORY/AWSDK.zip"
rm -f "$DESTINATION_DIRECTORY/AWSDK.pdf"

echo "Finished downloading latest SDK frameworks."

