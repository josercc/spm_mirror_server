import Vapor
import SwiftShell

func routes(_ app: Application) throws {
    app.post("mirror") { req -> ResponseModel<String> in
        /// 验证请求的参数
        try Mirror.Request.validate(content: req)
        /// 获取请求的参数
        let content = try req.content.decode(Mirror.Request.self)
        /// 获取需要镜像的源地址
        let url = content.url
        /// 根据 URL 获取仓库名称 比如vapor/vapor -> vapor-vapor
        let repoName = mirrData(from: url)
            .components(separatedBy: "/")
            .joined(separator: "-")
        let giteeApi = try GiteeApi()
        /// 检查库是否存在
        let checkFetch = try await giteeApi.checkFetck(name: repoName, req: req)
        /// 如果库存在并且不是更新中
        guard !checkFetch.emptyRepo, !checkFetch.inFetch else {
            /// 获取同步数据
            let updateRepoResponse = try await giteeApi.getPathContent(use: req,
                                                                   owner: "swift-package-manager-mirror",
                                                                   repo: "mirror-repos",
                                                                   path: "update_repo.json")
            let updateRepoJson = try updateRepoResponse.content.decodeBase64String()
            guard let data = updateRepoJson.data(using: .utf8) else {
                throw Abort(.updateRepoJsonError)
            }
            var responses = try JSONDecoder().decode([UpdateRepoResponse].self, from: data)
            guard let index = responses.firstIndex(where: {$0.url == url}) else {
                /// 如果库存在 并且同步历史不存在 则进行同步
                /// /// 更新库
                let syncResult = try await giteeApi.syncProject(name: repoName, req: req)
                guard syncResult else {
                    throw Abort(.syncRepoError)
                }
                let updateResult = UpdateRepoResponse(url: url,
                                                      lastUpdateTime: Date().timeIntervalSince1970)
                responses.append(updateResult)
                let content = try transferResponse(responses: responses)
                let result = try await giteeApi.updateContent(content: content,
                                                              req: req,
                                                              repoPath: "mirror-repos",
                                                              path: "update_repo.json",
                                                              owner: "swift-package-manager-mirror",
                                                              sha: updateRepoResponse.sha,
                                                              message: "update \(url) async date")
                guard result else {
                    throw Abort(.custom(code: 20001, reasonPhrase: "更新仓库时间失败"))
                }
                return .init(success: mirrorRepo(repo: repoName))
            }
            var updateResult = responses[index]
            guard updateResult.lastUpdateTime + 24 * 60 * 60 < Date().timeIntervalSince1970 else {
                /// 如果更新时间小于24小时 则不需要更新
                return .init(success: mirrorRepo(repo: repoName))
            }
            /// 更新库
            let syncResult = try await giteeApi.syncProject(name: repoName, req: req)
            guard syncResult else {
                throw Abort(.syncRepoError)
            }
            /// 更新同步的时间
            updateResult.lastUpdateTime = Date().timeIntervalSince1970
            responses[index] = updateResult
            let content = try transferResponse(responses: responses)
            let result = try await giteeApi.updateContent(content: content,
                                                          req: req,
                                                          repoPath: "mirror-repos",
                                                          path: "update_repo.json",
                                                          owner: "swift-package-manager-mirror",
                                                          sha: updateRepoResponse.sha,
                                                          message: "update \(url) async date")
            guard result else {
                throw Abort(.custom(code: 20001, reasonPhrase: "更新仓库时间失败"))
            }
            return .init(success: mirrorRepo(repo: repoName))
        }
        /// 如果库存在并且在更新中
        guard !checkFetch.emptyRepo, checkFetch.inFetch else {
            return .init(failure: 102, message: "镜像已经存在，正在更新中，请稍等！")
        }
        /// 创建库
        let createResult = try await giteeApi.createProject(req: req, importUrl: url, name: repoName)
        guard createResult else {
            return .init(failure: 100, message: "创建\(url)镜像失败")
        }
        /// 更新mirror 库
        try await updateMirrorRepoDate(req: req,
                                       url: url,
                                       mirrorUrl: mirrorRepo(repo: repoName),
                                       giteeApi: giteeApi)
        
        /// 刷新库
        let createCheck = try await giteeApi.checkFetck(name: repoName, req: req, retryCount: 60)
        guard !createCheck.inFetch else {
            throw Abort(.createRepoFetching)
        }
        return ResponseModel(success: "\(content.url)")
    }
    
    func transferResponse(responses:[UpdateRepoResponse]) throws -> String {
        let data = try JSONEncoder().encode(responses)
        guard let content = String(data: data, encoding: .utf8) else {
            throw Abort(.toJsonStringError)
        }
        return try content.encodeBase64String()
    }
    
    func updateMirrorRepoDate(req:Request,
                              url:String,
                              mirrorUrl:String,
                              giteeApi:GiteeApi) async throws {
        let mirrorRepoData = try await giteeApi.getPathContent(use: req,
                                                               owner: "swift-package-manager-mirror",
                                                               repo: "mirror-repos",
                                                               path: "mirror_repo.json")
        let mirrorRepoContent = try mirrorRepoData.content.decodeBase64String()
        guard let data = mirrorRepoContent.data(using: .utf8) else {
            throw Abort(.systemError)
        }
        var mirrors = try JSONDecoder().decode([MirrorRepo].self, from: data)
        if let index = mirrors.firstIndex(where: {$0.origin == url}) {
            var mirror = mirrors[index]
            mirror.mirror = mirrorUrl
            mirrors[index] = mirror
        } else {
            let mirror = MirrorRepo(origin: url, mirror: mirrorUrl)
            mirrors.append(mirror)
        }
        let mirrorData = try JSONEncoder().encode(mirrors)
        let mirrorContent = mirrorData.base64EncodedString()
        let result = try await giteeApi.updateContent(content: mirrorContent,
                                                      req: req,
                                                      repoPath: "mirror-repos",
                                                      path: "mirror_repo.json",
                                                      owner: "swift-package-manager-mirror",
                                                      sha: mirrorRepoData.sha,
                                                      message: "update \(url) mirror")
        guard result else {
            throw Abort(.systemError)
        }
    }
}

