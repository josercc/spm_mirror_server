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
    
    init() {
        
    }
    
    init(origin:String, mirror:String) {
        self.origin = origin
        self.mirror = mirror
        self.create = Date().timeIntervalSince1970
        self.isExit = false
    }
}
