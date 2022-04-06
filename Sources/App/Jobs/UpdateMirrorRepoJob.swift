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
struct UpdateMirrorRepoJob: AsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        let mirror = payload.mirror
        /// 获取是否需要升级 不需要升级则退出
        guard let needUpdate = mirror.needUpdate, needUpdate else {
            return
        }
        let origin = mirror.origin
        /// 获取原来仓库的组织
        guard let src = repoOriginPath(from: origin) else {
            throw Abort(.expectationFailed)
        }
        /// 获取镜像之后的组织
        guard let dst = repoOriginPath(from: mirror.mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 获取仓库名称
        guard let repo = repoNamePath(from: origin) else {
            throw Abort(.expectationFailed)
        }
        /// 获取YML文件
        let ymlFilePath = try getYmlFilePath(url: origin)
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 获取之前仓库是否是组织
        let isOrg = try await githubApi.isOrg(name: src, client: context.application.client)
        /// 生成内容
        let ymlContent = actionContent(src: src, dst: dst, isOrg: isOrg, repo: repo, mirror: mirror.mirror)
        /// 检测 YML 是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlFilePath, in: context.application.client)
        if !ymlExit {
            /// 如果不存在则添加YML
            guard try await githubApi.addGithubAction(fileName: ymlFilePath, content: ymlContent, client: context.application.client) else {
                throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFilePath)失败"))
            }
        }
        /// 30秒后删除 启动任务之后不久就删除
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.application.eventLoopGroup.next(), {
            sleep(30)
        }).get()
        try await githubApi.deleteYml(fileName: ymlFilePath, in: context.application.client)
        /// 更新Mirror 最后更新日期
        mirror.lastMittorDate = Date().timeIntervalSinceReferenceDate
        try await mirror.update(on: context.application.db)
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: PayloadData) async throws {
        let message = "\(payload.mirror) \(error.localizedDescription)"
        let wxApi = try WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        wxApi.sendContent(message, in: context.application.client)
    }
}


extension UpdateMirrorRepoJob {
    struct PayloadData: Codable {
        let config:MirrorConfigration
        let mirror:Mirror
    }
}
