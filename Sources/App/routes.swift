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
        /// 库不存在需要启动Github Action 同步库
        guard let user = gitUser(from: url) else {
            return .init(failure: 10000, message: "\(url)不是一个正规的Github仓库地址")
        }
        let isOrg = try await isOrg(name: user, req: req)
        let actionContent = actionContent(user: user,
                                          isOrg: isOrg,
                                          repo: mirrData(from: url),
                                          mirror: repoName)
        try await giteeApi.addGithubAction(fileName: "\(repoName)-sync.yml",
                                           req: req,
                                           content: actionContent)
        return ResponseModel(success: "\(content.url)")
    }
    
}


