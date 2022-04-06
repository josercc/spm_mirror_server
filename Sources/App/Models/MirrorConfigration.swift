//
//  MirrorConfigration.swift
//  
//
//  Created by king on 2022/4/6.
//

import Foundation
import Vapor

public struct MirrorConfigration: Codable {
    public let giteeToken:String
    public let githubToken:String
    public let githubRepo:String
    public let wxHookUrl:String
    
    init() throws {
        guard let giteeToken = Environment.get("GITEE_TOKEN") else {
            print("GITEE_TOKEN 不存在")
            throw Abort(.expectationFailed)
        }
        self.giteeToken = giteeToken
        guard let githubToken = Environment.get("GITHUB_TOKEN") else {
            print("GITHUB_TOKEN 不存在")
            throw Abort(.expectationFailed)
        }
        self.githubToken = githubToken
        guard let githubRepo = Environment.get("GITHUB_REPO") else {
            print("GITHUB_REPO不存在")
            throw Abort(.expectationFailed)
        }
        self.githubRepo = githubRepo
        guard let wxHookUrl = Environment.get("WEIXIN_HOOK") else {
            print("WEIXIN_HOOK 不存在")
            throw Abort(.expectationFailed)
        }
        self.wxHookUrl = wxHookUrl
    }
}
