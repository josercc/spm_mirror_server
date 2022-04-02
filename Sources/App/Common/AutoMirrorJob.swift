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
public class AutoMirrorJob {
    let githubApi:GithubApi
    let giteeApi:GiteeApi
    let app:Application
    let wxHook:WeiXinWebHooks
    public init(app:Application) throws {
        giteeApi = try GiteeApi()
        githubApi = try GithubApi()
        self.app = app
        self.wxHook = try WeiXinWebHooks()
    }
    /// 执行任务
    public func start() {
        Task {
            app.logger.info("开始启动自动任务")
            await autoMirrorStatus.start()
            do {
                /// 开始进行制作镜像
                try await mirror()
            } catch(let e) {
                if let abort = e as? Abort {
                    app.logger.info("自动任务异常:\(abort.reason) 正在上报到微信监控群...")
                    wxHook.sendContent(abort.reason, in: app.client)
                }
                app.logger.info("查询是否可以继续进行自动任务")
                let canRun = await autoMirrorStatus.canRun
                guard canRun else {
                    app.logger.info("不可以进行自动任务，自动任务结束。")
                    return
                }
                app.logger.info("可以进行自动任务，重新开始自动任务。")
                start()
            }
        }
    }
    
    func mirror() async throws {
        app.logger.info("查询是否有需要进行自动更新仓库")
        while true {
            let date = Date().timeIntervalSince1970 - 7 * 24 * 60 * 60
            let needUpdateMirror = try await Mirror.query(on: app.db).filter(\.$requestMirrorCount > 1000).filter(\.$lastMittorDate < date).first()
            guard var mirror = needUpdateMirror else {
                break
            }
            try await updateMirror(mirror: &mirror)
        }
        app.logger.info("准备进行查询是否还有未完成镜像")
        while true {
            app.logger.info("查询镜像还没有完成镜像")
            let waitingMirror = try await Mirror.query(on: app.db).filter(\.$isExit == false).first()
            guard let waitingMirror = waitingMirror else {
                app.logger.info("查询镜像的任务都已经完成了，退出开始新的镜像任务。")
                break
            }
            app.logger.info("查询到\(waitingMirror.origin)镜像还没有制作完成")
            app.logger.info("查询镜像是否在 Gitee 中存在")
            let isExit = try await giteeApi.checkRepoExit(url: waitingMirror.mirror, in: app.client)
            guard !isExit else {
                app.logger.info("\(waitingMirror.mirror)已经存在")
                let ymlFilePath = try getYmlFilePath(url: waitingMirror.origin)
                app.logger.info("删除\(ymlFilePath)文件")
                try await githubApi.deleteYml(fileName: ymlFilePath, in: app.client)
                app.logger.info("更新镜像信息")
                waitingMirror.isExit = true
                try await waitingMirror.update(on: app.db)
                continue
            }
            app.logger.info("\(waitingMirror.mirror)不存在，等待30秒重试")
            let _ = try await app.threadPool.runIfActive(eventLoop: app.eventLoopGroup.next(), {
                sleep(30)
            }).get()
        }
        app.logger.info("查询等待镜像的队列")
        guard let stack = try await MirrorStack.query(on: app.db).sort(\.$create).first() else {
            app.logger.info("镜像队列没有任务，自动任务退出!")
            await autoMirrorStatus.stop()
            return
        }
        /// 获取到需要镜像的仓库地址
        let originUrl = stack.url
        app.logger.info("需要镜像仓库地址：\(originUrl)")
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
        app.logger.info("查询用户拥有的组织信息")
        let orgs = try await giteeApi.getUserOrg(client: app.client)
        /// 默认组织名称的数字
        var index = 0
        /// 默认的组织名称
        var orgName = "spm_mirror"
        while true {
            /// 准备制作镜像的地址
            let mirrorPath = "https://gitee.com/\(orgName)/\(name)"
            app.logger.info("准备制作:\(mirrorPath)")
            /// 获取准备制作的镜像是否已经存在
            if let mirror = try await Mirror.query(on: app.db).filter(\.$mirror == mirrorPath).first() {
                app.logger.info("镜像地址已经被占用,占用仓库为\(mirror.origin)")
                /// 制作的镜像已经存在被其他占用 更换镜像组织
                index += 1
                orgName += "\(index)"
                continue
            }
            /// 判断当前的组织是否需要进行创建
            app.logger.info("判断\(orgName)是否存在")
            if !orgs.contains(where: {$0.name == orgName}) {
                /// 创建不存在的组织
                app.logger.info("创建组织:\(orgName)")
                try await giteeApi.createOrg(client: app.client, name: orgName)
            }
            app.logger.info("查询\(ymlFile)是否存在")
            let ymlExit = try await githubApi.ymlExit(file: ymlFile, in: app.client)
            if !ymlExit {
                app.logger.info("\(ymlFile)已经存在")
                app.logger.info("查询\(src)是否是组织")
                let isOrg = try await githubApi.isOrg(name: src, client: app.client)
                /// yml的内容
                let ymlContent = actionContent(src: src,
                                                   dst: orgName,
                                                   isOrg: isOrg,
                                                   repo: name,
                                                   mirror: name)
                app.logger.info("创建\(ymlFile)文件")
                guard try await githubApi.addGithubAction(fileName: ymlFile,
                                                          content: ymlContent,
                                                          client: app.client) else {
                    throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFile)文件失败"))
                }
            }
            app.logger.info("\(ymlFile)已经存在")
            let mirror = Mirror(origin: originUrl, mirror: mirrorPath)
            app.logger.info("保存镜像数据到数据库")
            try await mirror.save(on: app.db)
            app.logger.info("删除制作镜像队列")
            try await stack.delete(on: app.db)
        }
    }
    
    func updateMirror( mirror:inout Mirror) async throws {
        /// 准备制作镜像的地址
        let mirrorPath = mirror.mirror
        app.logger.info("准备更新:\(mirrorPath)")
        /// 获取到需要镜像的仓库地址
        let originUrl = mirror.origin
        app.logger.info("需要镜像仓库地址：\(originUrl)")
        /// 获取仓库的组织或者用户名称 比如 Vapor
        guard let src = repoOriginPath(from: originUrl) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(originUrl)中获取组织或者用户失败"))
        }
        /// 获取仓库名称 比如 Vapor
        guard let name = repoNamePath(from: originUrl) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(originUrl)中获取仓库名称失败"))
        }
        
        guard let orgName = repoNamePath(from: mirror.mirror) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(mirror.mirror)中获取仓库名称失败"))
        }
        /// 生成对应的 Gtihub Action配置文件名称
        let ymlFile = try getYmlFilePath(url: mirror.origin)
        app.logger.info("查询\(ymlFile)是否存在")
        let ymlExit = try await githubApi.ymlExit(file: ymlFile, in: app.client)
        if !ymlExit {
            app.logger.info("\(ymlFile)已经存在")
            app.logger.info("查询\(src)是否是组织")
            let isOrg = try await githubApi.isOrg(name: src, client: app.client)
            /// yml的内容
            let ymlContent = actionContent(src: src,
                                               dst: orgName,
                                               isOrg: isOrg,
                                               repo: name,
                                               mirror: name)
            app.logger.info("创建\(ymlFile)文件")
            guard try await githubApi.addGithubAction(fileName: ymlFile,
                                                      content: ymlContent,
                                                      client: app.client) else {
                throw Abort(.custom(code: 10000, reasonPhrase: "创建\(ymlFile)文件失败"))
            }
        }
        mirror.isExit = false
        mirror.lastMittorDate = Date().timeIntervalSince1970
        try await mirror.update(on: app.db)
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
