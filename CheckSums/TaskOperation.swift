//
//  TaskOperation.swift
//  CheckSums
//
//  Created by Mark Lim on 1/22/17.
//  Copyright © 2017 IncrementalInnovation. All rights reserved.
//

import Foundation
import CommonCrypto

class TaskOperation: Operation {
    var theDelegate : AppDelegate?
    var url: URL?
    var digest: String?
    
    init(pathURL : URL, delegate: AppDelegate, digest: String) {
        super.init()
        self.theDelegate = delegate
        self.digest = digest
        self.url = pathURL
    }

  
    func hexString(fromArray : [UInt8], uppercase : Bool = false) -> String {
        return fromArray.map() {
            String(format:uppercase ? "%02X" : "%02x", $0)
            }.reduce("", +)
    }


    // mark - the message digest generation methods
    // this is faster
    func hashUsing(algorithm: Digest.Algorithm) -> String? {
        var handle: FileHandle? = nil
        do {
            handle = try FileHandle(forReadingFrom: url!)
        }
        catch _ {
            //print("can't get a file handle")
            return nil
        }
        var done = false
        let chunkSize = 100 * 1024 * 1024       // 100 MB per chunk.
        let d = Digest(algorithm: algorithm)
        while (!done) {
            autoreleasepool {
                let fileChunk = handle!.readData(ofLength: chunkSize)
                //print("one chunk")
                _ = d.update(fileChunk)
                if fileChunk.count == 0 {
                    done = true
                }
            }
        }
        handle!.closeFile()
        let code = d.final()
        let str = hexString(fromArray: code)
        return str
    }

    override func main() {
        if !self.isCancelled {
            var hashAlgorithm: Digest.Algorithm
            switch digest! {
            case "md5":
                hashAlgorithm = .md5
            //hash = digestFunction!(data: data, dataLength: UInt32(nsdata.length))
            case "sha1":
                hashAlgorithm = .sha1
            case "sha256":
                hashAlgorithm = .sha256
            case "sha512":
                hashAlgorithm = .sha512
            default:
                hashAlgorithm = .sha1
            }

            let checkSumString = hashUsing(algorithm: hashAlgorithm)
            DispatchQueue.main.async() {
                if self.theDelegate!.isBatchMode {
                    self.theDelegate!.fullPathnames!.append(self.url!.path)
                    self.theDelegate!.checkSums!.append(checkSumString!)
                }
                else {
                    self.theDelegate!.messageDigestCheckSum.stringValue = checkSumString!
                }
                self.theDelegate!.tasksTerminatedCount += 1
                //print(self.url!.path, checkSumString)
                if self.theDelegate!.tasksTerminatedCount == self.theDelegate!.totalTasksCount {
                    // This sub-process is the last one, send a notification to the observer.
                    let noteCenter = NotificationCenter.default
                    let notification = NSNotification(name: NSNotification.Name(rawValue: csNotificationName),
                                                      object: nil)      // notificationSender
                    noteCenter.post(notification as Notification)
                }
            }
        }
        else {
            print("operation was cancelled")
        }
    }
}
