//
//  MirrorStack.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import FluentKit
import ConsoleKit

final class MirrorStack:Model {
    static var schema: String {"mirror_stack"}
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
