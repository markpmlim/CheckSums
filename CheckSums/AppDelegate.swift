//
//  AppDelegate.swift
//  CheckSums
//
//  Created by Mark Lim on 1/22/17.
//  Copyright © 2017 IncrementalInnovation. All rights reserved.
//

import Cocoa
import CommonCrypto

let csNotificationName = "CheckSumsNotificationName"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var path: NSTextField!
    @IBOutlet var messageDigestCheckSum: NSTextField!
    @IBOutlet var generateButton: NSButton!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var slider: NSSlider!

    var currentDigest = "sha1"          // defaults to SHA1
    var taskQueue: OperationQueue?

    // variables for batch files processing
    var fullPathnames: [String]?
    var checkSums: [String]?
    var currentConcurrencyValue = 4
    var urlCheckSums: URL?
    
    var isCancelled = false
    var isBatchMode = false
    var tasksTerminatedCount = 0
    var totalTasksCount = 0

    deinit {
        let noteCenter = NotificationCenter.default
        noteCenter.removeObserver(self)
    }
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        taskQueue = OperationQueue()
        cancelButton.isEnabled = false
        let noteCenter = NotificationCenter.default
        // noteCenter will send the "allTasksCompleted:" message to the notificationObserver
        // (which is the single instance of AppDelegate) when notifications with the name
        // csNotificationName are received by noteCenter.
        noteCenter.addObserver(self,            // notificationObserver
                               selector: #selector(AppDelegate.allTasksCompleted(_:)),
                               name: Notification.Name(rawValue: csNotificationName),
                               object: nil)     // notificationSender
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func confirmExit() -> Bool {
        let alert = NSAlert()
        var reply: Bool?
        alert.messageText = "You have still have at least one process running"
        alert.informativeText = "Do you want to quit?"
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == NSAlertFirstButtonReturn {
            reply = true
        }
        else {
            print("Cancelled was selected")
            reply = false
        }
        return reply!
    }

    // Ask for confirmation on Window closing
    func windowShouldClose(sender: AnyObject) -> Bool {
        var status: Bool?
    
        if taskQueue!.operationCount != 0 {
            if confirmExit() {
                //print("terminating file(s) processing")
                taskQueue!.cancelAllOperations()
                status =  true
            }
            else {
                status = false
            }
        }
        else {
            // no task in queue so ok to quit
            status = true
        }
        return status!
    }

    // User has chosen Cmd+Q, just quit w/o asking
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        //print("applicationShouldTerminate")
        var reply: NSApplicationTerminateReply?
        if taskQueue!.operationCount != 0 {
            print("terminating file(s) processing")
            taskQueue!.cancelAllOperations()
            reply = .terminateNow
        }
        else {
            // no task in queue so ok to quit
            reply = .terminateNow
        }
        return reply!
    }
    
    func processFileAt(_ path: String) {
        // single ordinary file
        isBatchMode = false
        cancelButton.isEnabled = true
        generateButton.isEnabled = false
        spinner.startAnimation(self)
        totalTasksCount = 1
        messageDigestCheckSum.stringValue = ""

        let url = URL(fileURLWithPath: path)
        let oper = TaskOperation(pathURL: url,
                                 delegate: self,
                                 digest: self.currentDigest)
        taskQueue!.addOperation(oper)
    }

    func batchProcessingAt(_ directoryURL: URL) {
        // Ordinary Directory: First get the name of the checksum file to be saved.
        let sp = NSSavePanel()
        sp.canCreateDirectories = true
        sp.allowedFileTypes = ["txt"]
        sp.nameFieldStringValue = "CheckSums.txt"
        let option = sp.runModal()
        if option == NSFileHandlingPanelOKButton {
            self.urlCheckSums = sp.url
        }
        else {
            return
        }
        
        let fmgr = FileManager.default
        // Do a deep enumeration of dir ignoring file packages, hidden files.
        let keys = [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        let dirEnum = fmgr.enumerator(at: directoryURL,
                                      includingPropertiesForKeys: keys,
                                      options: options,
                                      errorHandler: {
            url, error in
            NSLog("\(error) during enumeration with:\(url)")
            return true
        })

        var urls = [URL]()
        var isResourceErr = false
        // Do a cumulative count and build up the "urls" array
        for case let url as URL in dirEnum! {
            do {
                let resourceValues = try url.resourceValues(forKeys: [URLResourceKey.isRegularFileKey])
                guard let isRegularFileResourceValue = resourceValues.isRegularFile
                else {
                    // ignore a directory or symlink
                    continue
                }
                guard isRegularFileResourceValue
                else {
                    // nil object
                    continue
                }
                // regular file:
                //print(url.path!)
                // Note: totalTasksCount is the number of NSTask objects to be instantiated.
                // Its value will be used by one of the sub-processes to determine if it's the last one.
                totalTasksCount += 1
                urls.append(url)
            }
            catch let error as NSError {
                // no error handler here. set an error flag
                isResourceErr = true
                // add a message to the system.log
                NSLog("\(error) for \(url.path): during checking for regular files")
            }
        } // for
        
        if isResourceErr {
            // KIV: put up error dialog here?
        }

        // Update the UI first and create 2 parallel arrays for recording
        // the path names and their checksums. Can't use dictionary!
        cancelButton.isEnabled = true
        generateButton.isEnabled = false
        spinner.startAnimation(self)
        messageDigestCheckSum.stringValue = ""
        taskQueue!.maxConcurrentOperationCount = currentConcurrencyValue
        isBatchMode = true
        fullPathnames = [String]()
        checkSums = [String]()
        for url in urls {
            let oper = TaskOperation(pathURL: url,
                                     delegate: self,
                                     digest: self.currentDigest)
            taskQueue!.addOperation(oper)
        }
    }

    @IBAction func generateAction(_ sender: AnyObject) {
        totalTasksCount = 0
        tasksTerminatedCount = 0
        isCancelled = false
        // Insert code here to initialize your application
        let pathname = path.stringValue
        let fmgr = FileManager.default
        if !pathname.isEmpty {
            var isDir = ObjCBool(false)
            // check file/folder exists
            if fmgr.fileExists(atPath: pathname, isDirectory: &isDir) {
                if !isDir.boolValue {
                    processFileAt(pathname)
                }
                else {
                    // The user has dropped a directory URL onto the "path" NSTextField.
                    let dirURL = URL(fileURLWithPath: pathname)
                    // Check if it's an ordinary folder and not a file package
                    //print("handling directory", dirURL)
                    var isFilePackageValue: Bool?
                    do {
                        let resourceValues = try dirURL.resourceValues(forKeys: [URLResourceKey.isPackageKey])
                        guard let isFilePackage = resourceValues.isPackage
                        else {
                            return
                        }
                        isFilePackageValue = isFilePackage
                    }
                    catch _ {
                        return
                    }
                    if isFilePackageValue! {
                        print("Ignoring file/document package")
                    }
                    else {
                        // An ordinary folder so proceed.
                        batchProcessingAt(dirURL)
                    } //
                }
            }
            else {
                // KIV: put up alert
                print("invalid path")
            }
        }
        else {
            // KIV: put up alert
            print("empty text field")
        }
    }

    @IBAction func abort(_ sender: AnyObject) {
        if taskQueue!.operationCount != 0 {
            //print("Cancelling all operations in queue")
            for oper in taskQueue!.operations {
                oper.cancel()
            }
        }
        cancelButton.isEnabled = false
        generateButton.isEnabled = true
        spinner.stopAnimation(self)
    }

    @IBAction func commonAction(_ sender: AnyObject) {
        enum MessageOptions: String {
            case md5 = "md5"
            case sha1 = "sha1"
            case sha256 = "sha256"
            case sha512 = "sha512"
        }
        
        let button = sender as! NSButton
        switch button.tag {
        case 0:
            currentDigest = MessageOptions.md5.rawValue
        case 1:
            currentDigest = MessageOptions.sha1.rawValue
        case 2:
            currentDigest = MessageOptions.sha256.rawValue
        case 3:
            currentDigest = MessageOptions.sha512.rawValue
        default:
            currentDigest = MessageOptions.sha1.rawValue
        }
    }

    @IBAction func sliderAction(_ sender: NSSlider) {
        currentConcurrencyValue = Int(sender.floatValue)
        if currentConcurrencyValue == 0 {
            currentConcurrencyValue = 4
        }
    }
    
    @IBAction func openHelpWindow(_ sender: AnyObject) {
        let helpPathname = Bundle.main.path(forResource: "Docs",
                                            ofType: "rtfd")
        NSWorkspace.shared().openFile(helpPathname!,
                                      withApplication: "TextEdit")
        
    }

    func allTasksCompleted(_: NSNotification) {
        //print("allTasksCompleted")
        cancelButton.isEnabled = false
        generateButton.isEnabled = true
        spinner.stopAnimation(self)
        if isCancelled {
            // this block may never be executed
            DispatchQueue.main.async() {
                let alert = NSAlert()
                alert.messageText = "The generation of message digests has cancelled."
                alert.informativeText = "Warning: One or more task(s) may still be executing."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        if !isBatchMode {
            return
        }
        if tasksTerminatedCount == totalTasksCount {
            //print(totalTasksCount)
            if !fullPathnames!.isEmpty {
                let fileData = NSMutableData()
                for i in 0..<totalTasksCount {
                    let output = checkSums![i] + " *" + fullPathnames![i] + "\n"
                    let lineData = output.data(using: String.Encoding.utf8)
                    fileData.append(lineData!)
                }
                fileData.write(to: urlCheckSums!, atomically: true)
                // In case, the method gets called on a background thread.
                DispatchQueue.main.async() {
                    // message text
                    let alert = NSAlert()
                    let checksumFilename = (self.urlCheckSums!.path as NSString).lastPathComponent
                    // informative text
                    alert.messageText = "The checksums file: " + checksumFilename + " has been written out successfully."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
