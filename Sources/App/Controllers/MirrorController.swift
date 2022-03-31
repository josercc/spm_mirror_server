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
    }
    func getMirror(req:Request) async throws -> ResponseModel<String> {
        /// 验证请求的仓库地址
        try MirrorContent.validate(query: req)
        /// 获取请求的内容
        let mirrorContent = try req.query.decode(MirrorContent.self)
        let originUrl = mirrorContent.url
        req.logger.debug("当前需要镜像的仓库:\(originUrl)")
        /// 查询当前仓库是否存在镜像
        req.logger.debug("正在查询当前仓库是否存在镜像....")
        if let mirror = try await Mirror.query(on: req.db).filter(\Mirror.$origin == originUrl).first() {
            req.logger.debug("当前仓库已经存在镜像:\(mirror.mirror)")
            return .init(success: mirror.mirror)
        }
        req.logger.debug("当前仓库不存在镜像，正在准备创建...")
        /// 查询用户拥有的组织信息
        let orgs = try await giteeApi.getUserOrg(req: req)
        let defaultOrgName = "spm_mirror"
        if !orgs.contains(where: {$0.name == defaultOrgName}) {
            try await giteeApi.createOrg(req: req, name: defaultOrgName)
        }
        guard let name = repoNamePath(from: originUrl) else {
            throw Abort(.systemError)
        }
        var index = 0
        var orgName = defaultOrgName
        while true {
            let mirrorPath = "https://gitee.com/\(orgName)/\(name)"
            req.logger.debug("正在检测镜像地址\(mirrorPath)是否存在...")
            if let mirror = try await Mirror.query(on: req.db).filter(\.$mirror == mirrorPath).first() {
                req.logger.debug("\(mirrorPath)已经存在, 对应的仓库为:\(mirror.origin)")
                index += 1
                orgName += "\(index)"
                continue
            }
            req.logger.debug("镜像地址\(mirrorPath)不存在,可以进行创建!")
            if !orgs.contains(where: {$0.name == orgName}) {
                try await giteeApi.createOrg(req: req, name: orgName)
            }
            guard let src = repoOriginPath(from: originUrl) else {
                throw Abort(.systemError)
            }
            let isOrg = try await githubApi.isOrg(name: src, req: req)
            let ymlContent = actionContent(src: src,
                                               dst: orgName,
                                               isOrg: isOrg,
                                               repo: name,
                                               mirror: name)
            let fileName = "sync-\(src)-\(name)"
            req.logger.debug("正在创建 \(fileName).yml 文件")
            guard try await githubApi.addGithubAction(fileName: fileName,
                                                      content: ymlContent,
                                                      req: req) else {
                req.logger.debug("创建\(fileName).yml文件失败")
                throw Abort(.systemError)
            }
            let mirror = Mirror()
            mirror.origin = originUrl
            mirror.mirror = mirrorPath
            try await mirror.save(on: req.db)
            return .init(success: mirrorPath)
        }
    }

}
