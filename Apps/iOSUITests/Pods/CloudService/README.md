# cloudconnect
cloud connect library 
** Creating cloud connect solutaion with sample interface for connecting to the cloud 

# Pushing new version of libarary

** Step1 

Update the tag version in podspec file 

** Step 2 

Made the changes and commit the change 


** Step 3

Create new tag example 1.0.0 

git tag 1.0.0

git push origin 1.0.0 


** Step 4 Validate the pod file 

## Run at podspec path without specifying pod file name 

pod spec lint

or 

## Without warnning 

pod spec lint CloudService.podspec

or 

## Allow warrning

pod spec lint CloudService.podspec  --allow-warnings






**Step 5 Validation success push the change with commands

## Run at podspec path without specifying pod file name 
pod trunk push 

or

## Allow warrning

pod trunk push CloudService.podspec --allow-warnings

Or 

## Without warnning 
pod trunk push CloudService.podspec
