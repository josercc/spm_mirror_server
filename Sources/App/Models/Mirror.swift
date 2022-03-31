//
//  Mirror.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import FluentKit

final class Mirror: Model {
    
    static var schema: String { "mirror" }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "origin")
    var origin:String
    
    @Field(key: "mirror")
    var mirror:String
    
    init() {
        
    }
}
