//
//  File.swift
//  
//
//  Created by admin on 2022/3/19.
//

import Foundation
import Vapor

extension HTTPResponseStatus {
    static let tokenNotExit:HTTPResponseStatus = .custom(code: 10000,
                                                         reasonPhrase: "GITEE_TOKEN 不存在")
    static let sessionNotExit:HTTPResponseStatus = .custom(code: 10001,
                                                           reasonPhrase: "GITEE_SESSION 不存在")
    static let getPathContentError:HTTPResponseStatus = .custom(code: 10002,
                                                                reasonPhrase: "获取路径下内容错误")
    static let updateRepoJsonError:HTTPResponseStatus = .custom(code: 10003,
                                                                reasonPhrase: "获取更新库数据出错!")
}
