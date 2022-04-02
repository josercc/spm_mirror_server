//
//  Mirror.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import FluentKit
import Vapor

final class Mirror: Model, Content {
    
    static var schema: String { "mirror" }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "origin")
    var origin:String
    
    @Field(key: "mirror")
    var mirror:String
    
    @Field(key: "create")
    var create:TimeInterval
    
    @Field(key: "is_exit")
    var isExit:Bool
    
    @OptionalField(key: "request_mirror_count")
    var requestMirrorCount:Int?
    
    @OptionalField(key: "last_mirror_date")
    var lastMittorDate:TimeInterval?
    
    init() {
        
    }
    
    init(origin:String, mirror:String) {
        self.origin = origin
        self.mirror = mirror
        self.create = Date().timeIntervalSince1970
        self.isExit = false
        self.requestMirrorCount = 0
        self.lastMittorDate = Date().timeIntervalSince1970
    }
    
    func needUpdate() -> Bool {
        guard let requestMirrorCount = requestMirrorCount else {
            return true
        }
        guard let lastMittorDate = lastMittorDate else {
            return true
        }
        return requestMirrorCount > 1000 && Date().timeIntervalSince1970 > (lastMittorDate + 7 * 24 * 60 * 60)
    }
}
