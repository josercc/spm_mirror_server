//
//  UpdateMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues
import Vapor

/// 更新镜像的操作
struct UpdateMirrorJob: MirrorAsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("UpdateMirrorJob: \(payload.mirror.origin) \(payload.mirror.mirror) \(String(describing: payload.mirror.id))")
        /// 获取需要更新的仓库
        let mirror = payload.mirror
        /// 获取是否需要升级 不需要升级则退出
        guard mirror.needUpdate else {
            return
        }
        /// 获取原仓库地址
        let origin = mirror.origin
        /// 获取原来仓库的组织
        guard let src = repoOriginPath(from: origin) else {
            throw Abort(.expectationFailed)
        }
        /// 获取镜像之后的组织
        guard let dst = repoOriginPath(from: mirror.mirror, host: "https://gitee.com/") else {
            throw Abort(.expectationFailed)
        }
        context.logger.info("UpdateMirrorJob: \(src) \(dst)");
        /// 获取GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        // /// 查询组织是否存在
        let exists = try await giteeApi.checkOrgExit(org: dst, in: context.application.client)
        // /// 如果不存在则创建
        if !exists {
            try await giteeApi.createOrg(client: context.application.client, name: dst)
        }
        /// 开启创建YML文件 
        let job = CreateYMLJob.PayloadData(config: payload.config, origin: mirror.origin, dst: dst)
        try await context.queue.dispatch(CreateYMLJob.self, job)
        /// 延时5秒开启新任务
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.application.eventLoopGroup.next(), {
            sleep(5)
        }).get()
        /// 创建新任务
        let newJob = MirrorJob.PayloadData(config: payload.config)
        /// 开启任务
        try await context.queue.dispatch(MirrorJob.self, newJob)
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: PayloadData) async throws {
        let message = "\(payload.mirror) \(error.localizedDescription)"
        let wxApi = WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        wxApi.sendContent(message, in: context.application.client)
    }
}


extension UpdateMirrorJob {
    struct PayloadData: JobPayload {
        let config:MirrorConfigration
        let mirror:Mirror
    }
}
