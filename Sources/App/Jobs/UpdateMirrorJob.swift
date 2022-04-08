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
        guard let dst = repoOriginPath(from: mirror.mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 获取GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        // /// 查询组织是否存在
        let exists = try await giteeApi.checkRepoExit(repo: dst, in: context.application.client)
        // /// 如果不存在则创建
        if !exists {
            try await giteeApi.createOrg(client: context.application.client, name: dst)
        }
        /// 获取仓库名称
        guard let repo = repoNamePath(from: origin) else {
            throw Abort(.expectationFailed)
        }
        /// 获取创建YML文件名称
        let ymlFilePath = try getYmlFilePath(url: origin)
        /// 创建 Github Api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 获取之前仓库是否是组织
        let isOrg = try await githubApi.isOrg(name: src, client: context.application.client)
        /// Github 新增Action内容
        let ymlContent = actionContent(src: src, dst: dst, isOrg: isOrg, repo: repo, mirror: mirror.mirror)
        /// 检测 YML 是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlFilePath, in: context.application.client)
        /// 如果不存在则添加YML
        if !ymlExit {
            /// 如果创建 YML 文件失败则退出
            guard try await githubApi.addGithubAction(fileName: ymlFilePath, content: ymlContent, client: context.application.client) else {
                throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFilePath)失败"))
            }
        }
        /// 30秒后删除 启动任务之后不久就删除 因为无法继续判断任务是否执行完成
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.application.eventLoopGroup.next(), {
            sleep(30)
        }).get()
        /// 删除 YML 文件
        try await githubApi.deleteYml(fileName: ymlFilePath, in: context.application.client)
        mirror.needUpdate = false
        /// 更新到数据库
        try await mirror.update(on: context.application.db)
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
