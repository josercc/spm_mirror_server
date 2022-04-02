//
//  MirrorRequest.swift
//  
//
//  Created by 张行 on 2022/4/2.
//

import Foundation
import FluentKit
import Vapor

final class MirrorRequest: Model {
    static var schema: String { "mirror_request" }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "url")
    var url:String
    
    @Field(key: "create")
    var create:TimeInterval
    
    init() {}
    
    init(url:String) {
        self.url = url
        self.create = Date().timeIntervalSince1970
    }
}
