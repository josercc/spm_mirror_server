//
//  String+Base64.swift
//  
//
//  Created by king on 2022/3/26.
//

import Foundation
import Vapor

extension String {
    func decodeBase64String() throws -> String {
        guard let data = Data(base64Encoded: self),
              let decodeString = String(data: data, encoding: .utf8) else {
            throw Abort(.expectationFailed)
        }
        return decodeString
    }
    
    func encodeBase64String() throws -> String {
        guard let data = self.data(using: .utf8) else {
            throw Abort(.expectationFailed)
        }
        return data.base64EncodedString()
    }
}
