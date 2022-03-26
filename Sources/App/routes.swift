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
            let updateRepoJson = try await giteeApi.getPathContent(use: req,
                                                      owner: "swift-package-manager-mirror",
                                                      repo: "mirror-repos",
                                                      path: "update_repo.json")
            guard let data = updateRepoJson.data(using: .utf8) else {
                throw Abort(.updateRepoJsonError)
            }
            let responses = try JSONDecoder().decode([UpdateRepoResponse].self, from: data)
//            guard let updateResult = responses.filter({$0.url == url}).first,
//                  updateResult.lastUpdateTime + 24 * 60 * 60 < Date().timeIntervalSince1970 else {
//                return .init(success: mirrorRepo(repo: repoName))
//            }
//            return .init(success: mirrorRepo(repo: repoName))
            return .init(failure: 10000, message: "")
        }
        /// 如果库存在并且在更新中
        guard !checkFetch.emptyRepo, checkFetch.inFetch else {
            return .init(failure: 102, message: "镜像已经存在，正在更新中，请稍等！")
        }
//        /// 创建库
//        let createResult = try await createProject(req: req, importUrl: url, name: repoName)
//        guard createResult else {
//            return .init(failure: 100, message: "创建\(url)镜像失败")
//        }
//        /// 刷新库
//        let createCheck = try await checkRepoExit(repo: repoName, req: req, retryCount: 60)
        return ResponseModel(success: "\(content.url)")
    }
        
//    func makeMirror(url:String, req:Request) async throws {
//        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
//            throw Abort(.custom(code: 101, reasonPhrase: "HOME 变量不存在"))
//        }
//        let cachePath = "\(home)/Library/Caches"
//        let mirrorPath = "\(cachePath)/spmmirror"
//        var customContext = CustomContext()
//        customContext.env = ProcessInfo.processInfo.environment
//        customContext.env["https_proxy"] = "http://127.0.0.1:7890"
//        customContext.env["http_proxy"] = "http://127.0.0.1:7890"
//        customContext.env["all_proxy"] = "socks5://127.0.0.1:7890"
//        if !checkIsExit(path: mirrorPath, isDir: true) {
//            customContext.currentdirectory = cachePath
//            print("mkdir spmmirror")
//            try customContext.runAndPrint("mkdir", "spmmirror")
//        }
//        let cloneName = mirrData(from: url)
//            .components(separatedBy: "/")
//            .joined(separator: "-")
//        let clonePath = "\(mirrorPath)/\(cloneName)"
//        if !checkIsExit(path: clonePath, isDir: true) {
//            customContext.currentdirectory = mirrorPath
//            print("git clone \(url) \(cloneName)")
//            try customContext.runAndPrint("git", "clone", url, cloneName)
//        }
//        let isRepoExit = try await checkRepoExit(repo: cloneName,
//                                                 req: req)
//        if !isRepoExit {
//            try await createRepo(repo: cloneName, req: req)
//        }
//        customContext.currentdirectory = clonePath
//        print("git remote show")
//        let showRemotesCommand = customContext.runAsync("git", "remote","show")
//        showRemotesCommand.resume()
//        let showRemotes = showRemotesCommand.stdout.read()
//        if !showRemotes.contains("gitee") {
//            print("git remote add gitee git@gitee.com:swift-package-manager-mirror/\(cloneName).git")
//            try customContext.runAndPrint("git",
//                                          "remote",
//                                          "add",
//                                          "gitee",
//                                          "git@gitee.com:swift-package-manager-mirror/\(cloneName).git")
//        }
//        print("git branch -a")
//        let command = customContext.runAsync("git", "branch", "-r")
//        command.resume()
//        /** example
//         origin/3
//         origin/HEAD -> origin/main
//         origin/LotU-atmain
//         origin/feature/storage-get-or-set-default
//         origin/form-decoder-int-empty-string
//         origin/gm
//         origin/main
//         origin/mediaType
//         origin/shared-allocator
//         origin/tn-accept-encoding
//         origin/tn-container
//         origin/tn-env-name
//         origin/tn-process
//         origin/tweak-content-definition
//         */
//        let stdout = command.stdout.read().replacingOccurrences(of: " ", with: "")
//        let branchs = stdout.components(separatedBy: "\n")
//            .filter({!$0.contains("->")})
//        let remoteBranchs = branchs.filter({$0.contains("origin")})
//        for remoteBranch in remoteBranchs {
//            let branch = remoteBranch.replacingOccurrences(of: "origin/", with: "")
//            /// 判断本地是否存在
//            let branchIsExit = branchs.filter({ $0 == branch }).count > 0
//            if branchIsExit {
//                print("git checkout \(branch)")
//                try customContext.runAndPrint("git", "checkout", branch)
//            } else {
//                print("git checkout -b \(branch) \(remoteBranch)")
//                try customContext.runAndPrint("git", "checkout","-b", branch, remoteBranch)
//            }
//            print("git pull origin \(branch)")
//            try customContext.runAndPrint("git", "pull", "origin", branch)
//            print("git push gitee \(branch)")
//            try customContext.runAndPrint("git", "push", "gitee", branch)
//        }
//    }
}

