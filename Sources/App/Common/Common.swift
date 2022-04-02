//
//  Common.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import ConsoleKit
import Vapor

func repoPath(from url:String) -> String {
    return url.replacingOccurrences(of: "https://github.com/", with: "")
        .replacingOccurrences(of: ".git", with: "")
}

func repoOriginPath(from url:String) -> String? {
    return repoPath(from: url).components(separatedBy: "/").first
}

func repoNamePath(from url:String) -> String? {
    return repoPath(from: url).components(separatedBy: "/").last
}

func actionContent(src:String,
                   dst:String,
                   isOrg:Bool,
                   repo:String,
                   mirror:String) -> String {
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

