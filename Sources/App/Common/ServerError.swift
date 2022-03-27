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
    static let syncRepoError:HTTPResponseStatus = .custom(code: 10004,
                                                  reasonPhrase: "同步仓库失败")
    static let toJsonStringError:HTTPResponseStatus = .custom(code: 10005,
                                                              reasonPhrase: "转变 JSON 字符串失败")
    static let createRepoFetching:HTTPResponseStatus = .custom(code: 10006,
                                                               reasonPhrase: "创建仓库同步中，稍后再试")
    static let systemError:HTTPResponseStatus = .custom(code: 20000,
                                                        reasonPhrase: "系统错误")
}
