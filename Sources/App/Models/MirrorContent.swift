//
//  MirrorContent.swift
//
//
//  Created by admin on 2022/3/14.
//

import Foundation
import Vapor

struct MirrorContent: Content, Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("url",
                        as: String.self,
                        is: .github,
                        required: true)
    }
    
    let url:String
}

extension Validator {
    static var github: Validator<String> {
        .init { data in
            let name = repoPath(from: data).components(separatedBy: "/")
            guard data.contains("https://github.com"), name.count == 2 else {
                return GithubResult(failure: "url 不是一个 github Package 地址")
            }
            return GithubResult(success: "\(data) 验证 ok")
        }
    }
}

struct GithubResult: ValidatorResult {
    var isFailure: Bool
    var successDescription: String?
    var failureDescription: String?
    init(success message:String) {
        self.isFailure = false
        self.successDescription = message
    }
    
    init(failure message:String) {
        self.isFailure = true
        self.failureDescription = message
    }
}


