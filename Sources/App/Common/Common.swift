//
//  Common.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import ConsoleKit
import Vapor
import Queues

func repoPath(from url:String, host:String = "https://github.com/") -> String {
    return url.replacingOccurrences(of: host, with: "")
        .replacingOccurrences(of: ".git", with: "")
}

func repoOriginPath(from url:String, host:String = "https://github.com/") -> String? {
    return repoPath(from: url, host: host).components(separatedBy: "/").first
}

func repoNamePath(from url:String, host:String = "https://github.com/") -> String? {
    return repoPath(from: url, host: host).components(separatedBy: "/").last
}

func actionContent(src:String,
                   dst:String,
                   isOrg:Bool,
                   repo:String,
                   mirror:String? = nil) -> String {
    let mirror = mirror ?? repo
    return """
    #
    on:
      push:
        # delete this item if you don't want to trigger this workflow when modify this repo
        branches: master
      schedule:
        # * is a special character in YAML so you have to quote this string
        # UTC 17:00 -> CST (China) 1:00, see https://datetime360.com/cn/utc-cst-china-time/
        - cron: '0 17 * * *'
    name: Mirror \(src)/\(repo) to Gitee \(dst)/\(mirror)
    jobs:
      run:
        name: Sync-GitHub-to-Gitee
        runs-on: ubuntu-latest
        steps:
        - name: Mirror the Github repos to Gitee.
          uses: Yikun/hub-mirror-action@master
          with:
            src: github/\(src)
            dst: gitee/\(dst)
            dst_key: ${{ secrets.GITEE_PRIVATE_KEY }}
            dst_token: ${{ secrets.GITEE_TOKEN }}
            mappings: "\(repo)=>\(mirror)"
            static_list: "\(repo)"
            force_update: true
            clone_style: "ssh"
            debug: true
            src_account_type: "\(isOrg ? "org" : "user")"
            dst_account_type: "org"
    """
}


extension Logger {
    func debugResponse(response:ClientResponse) {
        if let body = response.body {
            debug(.init(stringLiteral: String(buffer: body)))
        }
    }
}


func getYmlFilePath(url:String) throws -> String {
    /// 获取仓库的组织或者用户名称 比如 Vapor
    guard let src = repoOriginPath(from: url) else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(url)中获取组织或者用户失败"))
    }
    /// 获取仓库名称 比如 Vapor
    guard let name = repoNamePath(from: url) else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(url)中获取仓库名称失败"))
    }
    /// 生成对应的 Gtihub Action配置文件名称
    let ymlFile = "sync-\(src)-\(name)" + ".yml"
    return ymlFile
}


extension ClientResponse {
    func printError(app:Application, uri:URI, codes:[UInt] = [200]) throws {
        guard let body = self.body else {
            throw Abort(.expectationFailed)
        }
        let content = String(buffer: body)
        guard codes.contains(self.status.code) else {
            app.logger.info("uri:\(uri)")
            app.logger.info("code:\(self.status.code)")
            app.logger.info("content:\(content)")
            throw Abort(.custom(code: self.status.code, reasonPhrase: "\(uri):\(content)"))
        }
    }
}

/// 检查镜像仓库是否存在
func checkMirrorRepoExit<T: JobPayload>(_ context: QueueContext, _ payload: T, _ origin:String, _ mirror:String) async throws -> CheckMirrorRepoExitStatus {
    let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
    guard let githubOrg = repoOriginPath(from: origin) else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(origin)中获取组织或者用户失败"))
    }
    guard let githubName = repoNamePath(from: origin) else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(origin)中获取仓库名称失败"))
    }
    let githubPackageContents = try await githubApi.getContents(name: githubOrg, repo: githubName, path: "Package.swift")
    guard let githubPakcageContent = githubPackageContents.first else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(origin) Package.swift 不存在"))
    }
    guard let giteeOrg = repoOriginPath(from: mirror, host: "https://gitee.com/") else {
        throw Abort(.custom(code: 10000, reasonPhrase: "\(mirror)中获取组织或者用户失败"))
    }
    let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
    /// 获取仓库是否存在
    guard try await giteeApi.checkRepoExit(owner: giteeOrg, repo: githubName, in: context.application.client) else {
        return .repoNotExit
    }
    let giteePackageContents = try await giteeApi.getFileContent(name: giteeOrg, repo: githubName, path: "Package.swift", in: context.application.client)
    guard let giteePakcageContent = giteePackageContents.first else {
        return .repoEmpty
    }
    guard githubPakcageContent.content.replacingOccurrences(of: "\n", with: "") == giteePakcageContent.content else {
        return .repoExitOther
    }
    return .repoExit
}


