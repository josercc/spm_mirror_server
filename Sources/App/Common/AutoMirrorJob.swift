//
//  AutoMirrorJob.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import Vapor
import FluentKit

/// 自动执行镜像的任务
class AutoMirrorJob {
    let githubApi:GithubApi
    let giteeApi:GiteeApi
    let app:Application
    let wxHook:WeiXinWebHooks
    init(app:Application) throws {
        giteeApi = try GiteeApi()
        githubApi = try GithubApi()
        self.app = app
        self.wxHook = try WeiXinWebHooks()
    }
    /// 执行任务
    func start() {
        Task {
            /// 将当前状态更改为可以执行工作
            await autoMirrorStatus.start()
            do {
                /// 开始进行制作镜像
                try await mirror()
            } catch(let e) {
                if let abort = e as? Abort {
                    /// 制作过程中发生了报错 将错误上传给
                   await wxHook.sendContent(abort.reason, in: app.client)
                }
                /// 是否是否可以继续进行任务
               let canRun = await autoMirrorStatus.canRun
                guard canRun else {
                    return
                }
                start()
            }
        }
    }
    
    func mirror() async throws {
        /// 等待制作镜像的任务完成
        while true {
            /// 查询正在等待制作的任务
            let waitingMirror = try await Mirror.query(on: app.db).filter(\.$isExit == false).first()
            /// 如果没有正在制作的任务则退出等待
            guard let waitingMirror = waitingMirror else {
                break
            }
            /// 查询制作是否完毕
            let isExit = try await giteeApi.checkRepoExit(url: waitingMirror.mirror, in: app.client)
            guard !isExit else {
                let ymlFilePath = try getYmlFilePath(url: waitingMirror.origin)
                /// 删除文件
                try await githubApi.deleteYml(fileName: ymlFilePath, in: app.client)
                /// 制作完毕 更新数据库数据
                waitingMirror.isExit = true
                try await waitingMirror.update(on: app.db)
                continue
            }
            sleep(30)
        }
        /// 按照创建时间获取第一条等待执行镜像的数据
        guard let stack = try await MirrorStack.query(on: app.db).sort(\.$create).first() else {
            /// 如果数据库此时没有 则暂停任务
            await autoMirrorStatus.stop()
            return
        }
        /// 获取到需要镜像的仓库地址
        let originUrl = stack.url
        /// 获取仓库的组织或者用户名称 比如 Vapor
        guard let src = repoOriginPath(from: originUrl) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(originUrl)中获取组织或者用户失败"))
        }
        /// 获取仓库名称 比如 Vapor
        guard let name = repoNamePath(from: originUrl) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(originUrl)中获取仓库名称失败"))
        }
        /// 生成对应的 Gtihub Action配置文件名称
        let ymlFile = try getYmlFilePath(url: originUrl)
        /// 查询用户拥有的组织信息
        let orgs = try await giteeApi.getUserOrg(client: app.client)
        /// 默认组织名称的数字
        var index = 0
        /// 默认的组织名称
        var orgName = "spm_mirror"
        while true {
            /// 准备制作镜像的地址
            let mirrorPath = "https://gitee.com/\(orgName)/\(name)"
            /// 获取准备制作的镜像是否已经存在
            if let _ = try await Mirror.query(on: app.db).filter(\.$mirror == mirrorPath).first() {
                /// 制作的镜像已经存在被其他占用 更换镜像组织
                index += 1
                orgName += "\(index)"
                continue
            }
            /// 判断当前的组织是否需要进行创建
            if !orgs.contains(where: {$0.name == orgName}) {
                /// 创建不存在的组织
                try await giteeApi.createOrg(client: app.client, name: orgName)
            }
            /// 查询是否已经创建yml 文件
            let ymlExit = try await githubApi.ymlExit(file: ymlFile, in: app.client)
            if !ymlExit {
                /// 查询仓库是否是组织
                let isOrg = try await githubApi.isOrg(name: src, client: app.client)
                /// yml的内容
                let ymlContent = actionContent(src: src,
                                                   dst: orgName,
                                                   isOrg: isOrg,
                                                   repo: name,
                                                   mirror: name)
                /// 创建Github Action Yml
                guard try await githubApi.addGithubAction(fileName: ymlFile,
                                                          content: ymlContent,
                                                          client: app.client) else {
                    throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFile)文件失败"))
                }
            }
            let mirror = Mirror(origin: originUrl, mirror: mirrorPath)
            /// 保存镜像数据到数据库
            try await mirror.save(on: app.db)
            /// 删除制作镜像队列
            try await stack.delete(on: app.db)
        }
    }
}


actor AutoMirrorStatus {
    var canRun:Bool = false
    
    init() {}
    
    func start() {
        canRun = true
    }
    
    func stop() {
        canRun = false
    }
}


let autoMirrorStatus = AutoMirrorStatus()
