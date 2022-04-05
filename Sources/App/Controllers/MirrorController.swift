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
    }
    /// 获取仓库的镜像
    func getMirror(req:Request) async throws -> ResponseModel<String> {
        /// 验证请求的仓库地址
        try MirrorContent.validate(query: req)
        /// 获取请求的内容
        let mirrorContent = try req.query.decode(MirrorContent.self)
        /// 请求需要进行的镜像仓库
        let originUrl = mirrorContent.url
        /// 保存请求记录
        let mirrorRequest = MirrorRequest(url: originUrl)
        try await mirrorRequest.save(on: req.db)
        /// 查询当前仓库是否存在镜像
        if let mirror = try await Mirror.query(on: req.db).filter(\Mirror.$origin == originUrl).first() {
            if var requestMirrorCount = mirror.requestMirrorCount {
                requestMirrorCount += 1
                mirror.requestMirrorCount = requestMirrorCount
                try await mirror.update(on: req.db)
            }
            return .init(success: mirror.mirror)
        }
        /// 如果仓库还没有制作镜像 则查询制作镜像队列
        guard let stack = try await MirrorStack.query(on: req.db).filter(\.$url == originUrl).first() else {
            /// 如果查询不到 则查询之前全部的数量
            let count = try await MirrorStack.query(on: req.db).all().count
            /// 将新的制作添加到队列
            let stack = MirrorStack(url: originUrl)
            try await stack.save(on: req.db)
            /// 开始进行自动任务
            let autoMirror = try AutoMirrorJob(app: req.application)
            autoMirror.start()
            /// 通知用户前面还有多人需要排队
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
}
