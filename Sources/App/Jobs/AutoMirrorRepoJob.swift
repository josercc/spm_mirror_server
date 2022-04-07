//
//  AutoMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues
import Vapor

struct MirrorJobData: Codable {
    let url:String
    let config:MirrorConfigration
    let mirrorOrg:String?
}


struct AutoMirrorRepoJob: AsyncJob {
    typealias Payload = MirrorJobData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        /// 获取需要镜像的仓库地址
        let mirror = payload.url
        /// 获取镜像的组织
        let mirrorOrg = payload.mirrorOrg ?? "spm_mirror"
        /// 获取 GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        /// 获取仓库名称
        guard let repo = repoNamePath(from: mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 获取镜像仓库地址
        let mirrorRepo = "https://gitee.com/\(mirrorOrg)/\(repo)"
        /// 判断镜像仓库是否存在
        let exists = try await giteeApi.checkRepoExit(repo: mirrorRepo, in: context.application.client)
        /// 如果镜像存在则退出
        if exists {
            return
        }
        /// 查询组织是否存在
        

    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let wzApi = try WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        wzApi.sendContent(error.localizedDescription, in: context.application.client)
    }
}
