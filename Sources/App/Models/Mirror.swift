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
    
    @OptionalField(key: "need_update")
    var needUpdate:Bool?
    
    @OptionalField(key: "wait_count")
    var waitCount:Int?
    
    init() {
        
    }
    
    init(origin:String, mirror:String) {
        self.origin = origin
        self.mirror = mirror
        self.create = Date().timeIntervalSince1970
        self.isExit = false
        self.requestMirrorCount = 0
        self.lastMittorDate = Date().timeIntervalSince1970
        self.needUpdate = false
        self.waitCount = 0
    }
}
