//
//  CommonFunction.swift
//  
//
//  Created by admin on 2022/3/14.
//

import Foundation
import Vapor

func mirrData(from url:String) -> String {
    return url.replacingOccurrences(of: "https://github.com/", with: "")
        .replacingOccurrences(of: ".git", with: "")
}

func checkIsExit(path:String, isDir:Bool) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: path,
                                          isDirectory: &isDirectory)
    && isDir == isDirectory.boolValue
}


func mirrorRepo(repo:String) -> String {
    return "https://gitee.com/swift-package-manager-mirror/\(repo)"
}

func isOrg(name:String, req:Request) async throws -> Bool {
    let uri = URI(string: "https://api.github.com/users/\(name)")
    print(uri)
    let response = try await req.client.get(uri, beforeSend: { request in
        var headers = HTTPHeaders()
        headers.add(name: .userAgent,
                    value: userAgent)
        request.headers = headers
    })
    let userInfo = try response.content.decode(GithubUserInfo.self)
    return userInfo.type == "Organization"
}

struct GithubUserInfo: Content {
    let type:String
}


func actionContent(user:String, isOrg:Bool, repo:String, mirror:String) -> String {
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
    name: Mirror GitHub Auto Queried Repos to Gitee
    jobs:
      run:
        name: Sync-GitHub-to-Gitee
        runs-on: ubuntu-latest
        steps:
        - name: Mirror the Github repos to Gitee.
          uses: Yikun/hub-mirror-action@master
          with:
            src: github/\(user)
            dst: gitee/swift-package-manager-mirror
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


func gitUser(from url:String) -> String? {
    /// https://github.com/vapor/vapor
    return mirrData(from: url).components(separatedBy: "/").first
    
}

let userAgent = """
"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15"
"""
