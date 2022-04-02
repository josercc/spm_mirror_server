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
    let giteeApi:GiteeApi
    let githubApi:GithubApi
    init() throws {
        giteeApi = try GiteeApi()
        githubApi = try GithubApi()
    }
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
    func getMirror(req:Request) async throws -> ResponseModel<String> {
        /// 验证请求的仓库地址
        try MirrorContent.validate(query: req)
        /// 获取请求的内容
        let mirrorContent = try req.query.decode(MirrorContent.self)
        let originUrl = mirrorContent.url
        let mirrorRequest = MirrorRequest(url: originUrl)
        try await mirrorRequest.save(on: req.db)
        /// 查询当前仓库是否存在镜像
        if let mirror = try await Mirror.query(on: req.db).filter(\Mirror.$origin == originUrl).first() {
            return .init(success: mirror.mirror)
        }
        guard let stack = try await MirrorStack.query(on: req.db).filter(\.$url == originUrl).first() else {
            let count = try await MirrorStack.query(on: req.db).all().count
            let stack = MirrorStack(url: originUrl)
            try await stack.save(on: req.db)
            let autoMirror = try AutoMirrorJob(app: req.application)
            autoMirror.start()
            return .init(failure: 10000, message: "\(originUrl)镜像正在排队制作中，前面还有\(count)排队")
        }
        let count = try await MirrorStack.query(on: req.db).filter(\.$create < stack.create).all().count
        return .init(failure: 10000, message: "\(originUrl)镜像正在排队制作中，前面还有\(count)排队")
    }

    func getList(req:Request) async throws -> ResponseModel<[Mirror]> {
        let paginate = try await Mirror.query(on: req.db).paginate(for: req)
        return .init(success: paginate.items, page: .init(page: paginate.metadata.page,
                                                          per: paginate.metadata.per,
                                                          total: paginate.metadata.total))
    }
}
