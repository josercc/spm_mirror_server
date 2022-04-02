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
    let page:Page?
    
    init(success data:T, message:String = "请求成功", page:Page? = nil) {
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

extension ResponseModel {
    struct Page: Content {
        let page: Int
        let per: Int
        let total: Int
        var pageCount: Int {
            let count = Int((Double(self.total)/Double(self.per)).rounded(.up))
            return count < 1 ? 1 : count
        }
    }
}
