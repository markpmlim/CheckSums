CheckSums is a Mac OS X application which can be use to generate check sums for files. It is written in Swift 3.0.


The program accepts as input the pathname of a single file or folder.


If a file from the macOS desktop is dragged and dropped onto the TextEdit control to the right of the label named "Path:"ù, CheckSums will generate a message digest for the file. The generated message digest will be displayed in the space to the right of the label named "Hash:".


If a folder is dropped onto the TextEdit control, all files within the enclosing directory will be processed and their check sums written to a text file. Please see accompanying documentation for a detailed description.


Currently, the following types of check sums may be generated from a file: MD5, SHA1, SHA256 and SHA512.


Build requirements: XCode 8.x or later.


Runtime system requirements: 10.9 or later.


References:

http://iosdeveloperzone.com/2014/10/03/using-commoncrypto-in-swift/

https://github.com/iosdevzone/IDZSwiftCommonCrypto


https://academy.realm.io/posts/danny-keogan-swift-cryptography/


https://medium.com/constant-improvement/how-to-get-commoncrypto-working-with-your-own-xcode-8-swift-3-0-framework-47b64fcbf024