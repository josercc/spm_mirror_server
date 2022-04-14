//
//  MirrorController.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import Vapor
import FluentKit

struct MirrorController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let mirror = routes.grouped("mirror")
        mirror.get { req -> ResponseModel<String> in
            do {
                let response = try await getMirror(req: req)
                return response
            } catch(let e) {
                return ResponseModel<String>(failure: 10000, message: e.localizedDescription)
            }
        }
        let list = routes.grouped("list")
        list.get { req -> ResponseModel<[Mirror]> in
            do {
                return try await getList(req: req)
            } catch (let e) {
                return .init(failure: 10000, message: e.localizedDescription)
            }
        }

        let job = routes.grouped("job")
        job.get(use: openMirrorJob)
    }
    /// 获取仓库的镜像
    func getMirror(req:Request) async throws -> ResponseModel<String> {
        /// 验证请求的仓库地址
        try MirrorContent.validate(query: req)
        /// 获取请求的内容
        let mirrorContent = try req.query.decode(MirrorContent.self)
        /// 请求需要进行的镜像仓库
        var originUrl = mirrorContent.url
        /// 去掉后缀 .git
        originUrl = originUrl.replacingOccurrences(of: ".git", with: "")
        /// 保存请求记录
        let mirrorRequest = MirrorRequest(url: originUrl)
        try await mirrorRequest.save(on: req.db)
        /// 查询当前仓库是否存在镜像
        if let mirror = try await Mirror.query(on: req.db).filter(\Mirror.$origin == originUrl).first() {
            mirror.requestMirrorCount += 1
            try await mirror.update(on: req.db)
            return .init(success: mirror.mirror)
        }
        /// 如果仓库还没有制作镜像 则查询制作镜像队列
        guard let stack = try await MirrorStack.query(on: req.db).filter(\.$url == originUrl).first() else {
            /// 如果查询不到 则查询之前全部的数量
            let count = try await MirrorStack.query(on: req.db).all().count
            /// 将新的制作添加到队列
            let stack = MirrorStack(url: originUrl)
            try await stack.save(on: req.db)
            let _ = try await openMirrorJob(req: req)
            return .init(failure: 10000, message: "\(originUrl)镜像正在排队制作中，前面还有\(count)个仓库正在排队")
        }
        /// 查询当前仓库已经在队列里面 查询前面还有多少仓库在排队
        let count = try await MirrorStack.query(on: req.db).filter(\.$create < stack.create).all().count
        return .init(failure: 10000, message: "\(originUrl)镜像正在排队制作中，前面还有\(count)个仓库正在排队")
    }
    /// 获取已经制作镜像列表
    func getList(req:Request) async throws -> ResponseModel<[Mirror]> {
        let paginate = try await Mirror.query(on: req.db).paginate(for: req)
        return .init(success: paginate.items, page: paginate.metadata)
    }

    func openMirrorJob(req:Request) async throws -> ResponseModel<String> {
        let isRunning = await mirrorJobStatus.isRunning
        if isRunning {
            return .init(failure: 10000, message: "当前存在运行的镜像任务 打开新的镜像任务失败！")
        }
        Task {
                /// 创建配置文件
                let config = try MirrorConfigration()
                await mirrorJobStatus.start()
                do {

                    /// 开启新的任务
                    let job = MirrorJob.PayloadData(config: config)
                    /// 开启任务
                    try await req.queue.dispatch(MirrorJob.self, job)
                } catch(let e) {
                    let hook  = WeiXinWebHooks(app: req.application, url: config.wxHookUrl)
                    hook.sendContent(e.localizedDescription, in: req.client)
                }
                await mirrorJobStatus.stop()
            }
        return .init(success: "开启任务成功")
    }
}
