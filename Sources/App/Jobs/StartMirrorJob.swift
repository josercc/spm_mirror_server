//
//  AutoMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues
import Vapor
import FluentKit

struct MirrorJobData: JobPayload {
    let mirrorStack:MirrorStack
    let config:MirrorConfigration
    let mirrorOrg:String?
}


struct StartMirrorJob: MirrorAsyncJob {
    typealias Payload = MirrorJobData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        context.logger.info("StartMirrorJob: \(payload.mirrorStack.url) \(payload.mirrorOrg ?? "som_mirror")")
        /// 获取需要镜像的仓库地址
        let mirror = payload.mirrorStack.url
        /// 获取镜像的组织
        let mirrorOrg = payload.mirrorOrg ?? "spm_mirror"
        /// 获取仓库名称
        guard let repo = repoNamePath(from: mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 获取镜像仓库地址
        let mirrorRepo = "https://gitee.com/\(mirrorOrg)/\(repo)"
        /// 检测镜像仓库是否被其他仓库占用
        let mirrorRepoExists = try await Mirror.query(on: context.application.db).filter(\.$mirror == mirrorRepo).filter(\.$origin != mirror).count() > 0
        /// 如果镜像仓库被其他仓库占用开启新的任务
        if mirrorRepoExists {
            context.logger.info("镜像仓库被其他仓库占用: \(mirrorRepo)")
            let mirrorJob = MirrorJobData(mirrorStack: payload.mirrorStack, config: payload.config, mirrorOrg: mirrorOrg + "1")
            /// 创建新的任务
            try await context.application.queues.queue.dispatch(StartMirrorJob.self, mirrorJob)
            return
        }
        /// 开启创建 YML任务
        let ymlJob = CreateYMLJob.PayloadData(config: payload.config, origin: payload.mirrorStack.url, dst: mirrorOrg)
        try await context.application.queues.queue.dispatch(CreateYMLJob.self, ymlJob)
        /// 如果镜像不存在则保存新镜像
        let count = try await Mirror.query(on: context.application.db).filter(\.$origin == mirror).count()
        if count == 0 {
            /// 保存新的镜像
            let mirrorData = Mirror(origin: mirror, mirror: mirrorRepo)
            try await mirrorData.save(on: context.application.db)
        }
        /// 延时5秒开启新的任务
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.application.eventLoopGroup.next(), {
            sleep(5)
        }).get()
        /// 创建新的任务
        let mirrorJob = MirrorJob.PayloadData(config: payload.config)
        try await context.application.queues.queue.dispatch(MirrorJob.self, mirrorJob)
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let wzApi = WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        wzApi.sendContent(error.localizedDescription, in: context.application.client)
    }
}
