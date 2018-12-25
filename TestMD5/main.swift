//
//  main.swift
//  TestSHA1
//
//  Created by Mark Lim on 1/22/17.
//  Copyright © 2017 SwiftP2P. All rights reserved.
//
//http://stackoverflow.com/questions/25248598/importing-commoncrypto-in-a-swift-framework
import Foundation
import CommonCrypto

extension String {
    
    func hnk_MD5String() -> String {
        if let data = self.data(using: String.Encoding.utf8) {
            let result = NSMutableData(length: Int(CC_MD5_DIGEST_LENGTH))
            let resultBytes = UnsafeMutablePointer<CUnsignedChar>(OpaquePointer(result!.mutableBytes))
            CC_MD5((data as NSData).bytes, CC_LONG(data.count), resultBytes)
            let resultEnumerator = UnsafeBufferPointer<CUnsignedChar>(start: resultBytes,
                                                                      count: result!.length)
            let MD5 = NSMutableString()
            for c in resultEnumerator {
                MD5.appendFormat("%02x", c)
            }
            return MD5 as String
        }
        return ""
    }
}

let str = "now has come the time"
print(str.hnk_MD5String())
