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
            throw Abort(.custom(code: 10000, reasonPhrase: "decodeBase64String error"))
        }
        return decodeString
    }
    
    func encodeBase64String() throws -> String {
        guard let data = self.data(using: .utf8) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "encodeBase64String error"))
        }
        return data.base64EncodedString()
    }
}
