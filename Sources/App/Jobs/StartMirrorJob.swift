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
        /// 获取 GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        /// 获取仓库名称
        guard let repo = repoNamePath(from: mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 获取镜像仓库地址
        let mirrorRepo = "https://gitee.com/\(mirrorOrg)/\(repo)"
        /// 如果是覆盖 数据库数据如果对应地址没有其他仓库占用则进行覆盖重写
        // /// 判断镜像仓库是否存在
        // let exists = try await giteeApi.checkRepoExit(repo: mirrorRepo, in: context.application.client)
        // /// 如果镜像存在则退出
        // if exists {
        //     return
        // }
        /// 查询组织是否存在
        let orgExists = try await giteeApi.checkOrgExit(org: mirrorOrg, in: context.application.client)
        /// 如果组织不存在则创建组织
        if !orgExists {
            try await giteeApi.createOrg(client: context.application.client, name: mirrorOrg)
        }
        /// 检测镜像仓库是否被其他仓库占用
        let mirrorRepoExists = try await Mirror.query(on: context.application.db).filter(\.$mirror == mirrorRepo).filter(\.$origin != mirror).count() > 0
        /// 如果镜像仓库被其他仓库占用开启新的任务
        if mirrorRepoExists {
            let mirrorJob = MirrorJobData(mirrorStack: payload.mirrorStack, config: payload.config, mirrorOrg: mirrorOrg + "1")
            /// 创建新的任务
            try await context.application.queues.queue.dispatch(StartMirrorJob.self, mirrorJob)
            return
        }
        /// 获取源仓库组织名称
        guard let originOrg = repoOriginPath(from: mirror) else {
            throw Abort(.expectationFailed)
        }
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 检查源仓库是否为组织
        let isOrg = try await githubApi.isOrg(name: originOrg, client: context.application.client)
        /// 获取Action 内容
        let actionContent = actionContent(src: originOrg, dst: mirrorOrg, isOrg: isOrg, repo: repo, mirror: repo)
        /// 创建YML 文件
        let ymlFile = try getYmlFilePath(url: mirror)
        /// 检测YML 文件是否存在
        let ymlExists = try await githubApi.ymlExit(file: ymlFile, in: context.application.client)
        /// 如果YML文件存在就删除数据库排队队列退出
        if ymlExists {
            /// 删除排队队列
            try await payload.mirrorStack.delete(on: context.application.db)
        }
        /// 创建YML文件
        let createSuccess = try await githubApi.addGithubAction(fileName: ymlFile, content: actionContent, client: context.application.client)
        /// 如果创建失败则退出
        if !createSuccess {
            throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFile)失败"))
        }
        /// 延时2分钟删除YML文件
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.application.eventLoopGroup.next(), {
            sleep(2 * 60)
        }).get()
        /// 删除 YML文件
        try await githubApi.deleteYml(fileName:ymlFile, in: context.application.client)
        /// 删除排队队列
        try await payload.mirrorStack.delete(on: context.application.db)
        /// 保存新的镜像
        let mirrorData = Mirror(origin: mirror, mirror: mirrorRepo)
        try await mirrorData.save(on: context.application.db)
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
