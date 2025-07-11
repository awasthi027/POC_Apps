# 1. How to get patch file
Clone the framework where you intend to implement changes.

Example: CocosLumberJack

git clone https://github.com/CocoaLumberjack/CocoaLumberjack.git
Step 2.

Make the necessary changes only in the required files; refrain from making any other modifications.

// Run this command to get deference file. file will be create in dir path

git diff > cocoalumberjack-custom.patch

Step 3. Copy repository and run Pod install 

# 2. It will patch. Details artilcle: https://medium.com/@awasthi027.ashish/applying-a-patch-to-an-already-published-pod-for-a-temporary-fix-in-your-project-post-pod-install-46a4163511fa
