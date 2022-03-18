import Vapor
import SwiftShell

func routes(_ app: Application) throws {
    app.post("mirror") { req -> ResponseModel<String> in
        try Mirror.Request.validate(content: req)
        let content = try req.content.decode(Mirror.Request.self)
        let url = content.url
        let packages = await mirror.packages
//        let checkFetch = await 
        guard !packages.contains(url) else {
            return .init(failure: 100,
                         message: "\(url) 镜像正在制作中，请稍后再试！")
        }
        await mirror.append(url)
        do {
            try await makeMirror(url: url, req: req)
        } catch(let e) {
            await mirror.remove(url)
            return .init(failure: 101, message: e.localizedDescription)
        }
        return ResponseModel(success: "\(content.url)")
    }
    
    func makeMirror(url:String, req:Request) async throws {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
            throw Abort(.custom(code: 101, reasonPhrase: "HOME 变量不存在"))
        }
        let cachePath = "\(home)/Library/Caches"
        let mirrorPath = "\(cachePath)/spmmirror"
        var customContext = CustomContext()
        customContext.env = ProcessInfo.processInfo.environment
        customContext.env["https_proxy"] = "http://127.0.0.1:7890"
        customContext.env["http_proxy"] = "http://127.0.0.1:7890"
        customContext.env["all_proxy"] = "socks5://127.0.0.1:7890"
        if !checkIsExit(path: mirrorPath, isDir: true) {
            customContext.currentdirectory = cachePath
            print("mkdir spmmirror")
            try customContext.runAndPrint("mkdir", "spmmirror")
        }
        let cloneName = mirrData(from: url)
            .components(separatedBy: "/")
            .joined(separator: "-")
        let clonePath = "\(mirrorPath)/\(cloneName)"
        if !checkIsExit(path: clonePath, isDir: true) {
            customContext.currentdirectory = mirrorPath
            print("git clone \(url) \(cloneName)")
            try customContext.runAndPrint("git", "clone", url, cloneName)
        }
        let isRepoExit = try await checkRepoExit(repo: cloneName,
                                                 req: req)
        if !isRepoExit {
            try await createRepo(repo: cloneName, req: req)
        }
        customContext.currentdirectory = clonePath
        print("git remote show")
        let showRemotesCommand = customContext.runAsync("git", "remote","show")
        showRemotesCommand.resume()
        let showRemotes = showRemotesCommand.stdout.read()
        if !showRemotes.contains("gitee") {
            print("git remote add gitee git@gitee.com:swift-package-manager-mirror/\(cloneName).git")
            try customContext.runAndPrint("git",
                                          "remote",
                                          "add",
                                          "gitee",
                                          "git@gitee.com:swift-package-manager-mirror/\(cloneName).git")
        }
        print("git branch -a")
        let command = customContext.runAsync("git", "branch", "-r")
        command.resume()
        /** example
         origin/3
         origin/HEAD -> origin/main
         origin/LotU-atmain
         origin/feature/storage-get-or-set-default
         origin/form-decoder-int-empty-string
         origin/gm
         origin/main
         origin/mediaType
         origin/shared-allocator
         origin/tn-accept-encoding
         origin/tn-container
         origin/tn-env-name
         origin/tn-process
         origin/tweak-content-definition
         */
        let stdout = command.stdout.read().replacingOccurrences(of: " ", with: "")
        let branchs = stdout.components(separatedBy: "\n")
            .filter({!$0.contains("->")})
        let remoteBranchs = branchs.filter({$0.contains("origin")})
        for remoteBranch in remoteBranchs {
            let branch = remoteBranch.replacingOccurrences(of: "origin/", with: "")
            /// 判断本地是否存在
            let branchIsExit = branchs.filter({ $0 == branch }).count > 0
            if branchIsExit {
                print("git checkout \(branch)")
                try customContext.runAndPrint("git", "checkout", branch)
            } else {
                print("git checkout -b \(branch) \(remoteBranch)")
                try customContext.runAndPrint("git", "checkout","-b", branch, remoteBranch)
            }
            print("git pull origin \(branch)")
            try customContext.runAndPrint("git", "pull", "origin", branch)
            print("git push gitee \(branch)")
            try customContext.runAndPrint("git", "push", "gitee", branch)
        }
    }
}

