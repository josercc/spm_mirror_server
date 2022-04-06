//
//  AutoMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues

struct MirrorJobData: Codable {
    let url:String
    let config:MirrorConfigration
}


struct AutoMirrorRepoJob: AsyncJob {
    typealias Payload = MirrorJobData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let app = context.application
        let giteeApi = try GiteeApi(app: app, token: payload.config.giteeToken)
        app.logger.info("查询镜像是否在 Gitee 中存在")
        let isExit = try await giteeApi.checkRepoExit(repo: waitingMirror.mirror.replacingOccurrences(of: "https://gitee.com/", with: ""), in: app.client)
        
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let wzApi = try WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        wzApi.sendContent(error.localizedDescription, in: context.application.client)
    }
}
