//
//  ResponseModel.swift
//
//
//  Created by admin on 2022/3/14.
//

import Foundation
import Vapor
import FluentKit

struct ResponseModel<T: Content>: Content {
    let code:Int
    let message:String
    let data:T?
    let isSuccess:Bool
    let page:PageMetadata?
    
    init(success data:T, message:String = "请求成功", page:PageMetadata? = nil) {
        self.code = 200
        self.message = message
        self.data = data
        self.isSuccess = true
        self.page = page
    }
    
    init(failure code:Int, message:String) {
        self.code = code
        self.message = message
        self.isSuccess = false
        self.data = nil
        self.page = nil
    }
}
