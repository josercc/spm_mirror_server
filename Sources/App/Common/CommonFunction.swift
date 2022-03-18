//
//  CommonFunction.swift
//  
//
//  Created by admin on 2022/3/14.
//

import Foundation
import Vapor

let giteeApi = "https://gitee.com/api/v5"
let accessToken = "839058c1cf1e49c7af9566e96b07e1ba"

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

func checkRepoExit(repo:String, req:Request) async throws -> CheckFetch {
    let url = "https://gitee.com/swift-package-manager-mirror/\(repo)/check_fetch"
    print("get \(url)")
    let response = try await req.client.get("url")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let checkFetch = try response.content.decode(CheckFetch.self, using: decoder)
    return checkFetch
}

struct CheckFetch: Content {
    let inFetch:Bool
    let emptyRepo:Bool
}

func createRepo(repo:String, req:Request) async throws {
    print("post \(giteeApi)/orgs/swift-package-manager-mirror/repos")
    let response = try await req.client.post("\(giteeApi)/orgs/swift-package-manager-mirror/repos", beforeSend: { request in
        try request.content.encode([
            "access_token": accessToken,
            "name": repo,
            "public": "1",
            "path": repo
        ])
    })
    guard response.status.code == 201 else {
        throw Abort(.custom(code: response.status.code, reasonPhrase: "创建 Gitee 仓库失败"))
    }
}


struct Repo: Content {
    
}
