import Vapor
import SwiftShell

func routes(_ app: Application) throws {
    let giteeApi = try GiteeApi()
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
            .joined(separator: "_")
        
        /// 检查库是否存在
        let checkFetch = try await giteeApi.checkFetck(name: repoName, req: req)
        guard checkFetch.emptyRepo else {
            return .init(success: mirrorRepo(repo: repoName))
        }
        let syncContent = try await giteeApi.getPathContent(use: req,
                                                        owner: "swift-package-manager-mirror",
                                                        repo: "mirror-repos",
                                                        path: "sync.json")
        let syncContentBase64 = try syncContent.content.decodeBase64String()
        guard let syncData = syncContentBase64.data(using: .utf8) else {
            return .init(failure: 10011, message: "decode sync.json failure")
        }
        var syncRepos = try JSONDecoder().decode([String].self, from: syncData)
        guard !syncRepos.contains(url) else {
            return .init(success: mirrorRepo(repo: repoName))
        }
        /// 库不存在需要启动Github Action 同步库
        guard let user = gitUser(from: url),
              let name = repoName.components(separatedBy: "_").last else {
            return .init(failure: 10000, message: "\(url)不是一个正规的Github仓库地址")
        }
        let isOrg = try await isOrg(name: user, req: req)
        let actionContent = actionContent(user: user,
                                          isOrg: isOrg,
                                          repo: name,
                                          mirror: repoName)
        try await giteeApi.addGithubAction(fileName: "\(repoName)-sync",
                                           req: req,
                                           content: actionContent)
        syncRepos.append(url)
        let data = try JSONEncoder().encode(syncRepos)
        guard let syncContentBase64Encode = try String(data: data, encoding: .utf8)?.encodeBase64String() else {
            throw Abort(.systemError)
        }
        guard try await giteeApi.updateContent(content: syncContentBase64Encode,
                                               req: req,
                                               repoPath: "mirror-repos",
                                               path: "sync.json",
                                               owner: "swift-package-manager-mirror",
                                               sha: syncContent.sha,
                                               message: "update \(url) in sync.json") else {
            throw Abort(.systemError)
        }
        return ResponseModel(success: mirrorRepo(repo: repoName))
    }
    
}


