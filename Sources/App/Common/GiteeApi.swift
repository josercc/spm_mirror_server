//
//  GiteeApi.swift
//  
//
//  Created by admin on 2022/3/19.
//

import Foundation
import Vapor

class GiteeApi {
    final let host = "https://gitee.com/api/v5"
    final let token:String
    final let session:String
    init() throws {
        guard let token = Environment.get("GITEE_TOKEN") else {
            throw Abort(.tokenNotExit)
        }
        self.token = token
        guard let session = Environment.get("GITEE_SESSION") else {
            throw Abort(.sessionNotExit)
        }
        self.session = session
    }
    
    func checkFetck(name:String, req:Request, retryCount:Int = 0) async throws -> CheckFetch {
        let url = "https://gitee.com/swift-package-manager-mirror/\(name)/check_fetch"
        print("get \(url)")
        let response = try await req.client.get(URI(string: url))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let checkFetch = try response.content.decode(CheckFetch.self, using: decoder)
        guard !checkFetch.inFetch else {
            return checkFetch
        }
        guard retryCount > 0 else {
            return checkFetch
        }
        /// 延时一秒再次请求
        let _ = try await req.application.threadPool.runIfActive(eventLoop: req.eventLoop, {
            sleep(1)
        }).get()
        return try await checkFetck(name: name, req: req, retryCount: retryCount - 1)
    }
    
    func getPathContent(use req:Request,
                        owner:String,
                        repo:String,
                        path:String) async throws -> PathContentResponse {
        let uri = URI(string: "\(host)/repos/\(owner)/\(repo)/contents/\(path)?access_token=\(token)")
        let response = try await req.client.get(uri)
        let content = try response.content.decode(PathContentResponse.self)
        return content
    }
    
    func syncProject(name:String, req:Request) async throws -> Bool {
        let uri = URI(string: "https://gitee.com/swift-package-manager-mirror/\(name)/force_sync_project")
        let response = try await req.client.post(uri, beforeSend: { request in
            request.headers.cookie = cookies()
        })
        return response.status.code == 200
    }
    
    func updateContent(content:String,
                       req:Request,
                       repoPath:String,
                       path:String,
                       owner:String,
                       sha:String,
                       message:String) async throws -> Bool {
        let url = "https://gitee.com/api/v5/repos/\(owner)/\(repoPath)/contents/\(path)"
        let response = try await req.client.put(URI(string: url), beforeSend: { request in
            try request.content.encode([
                "access_token": token,
                "content": content,
                "sha": sha,
                "message": message
            ])
        })
        return response.status.code == 200
    }
    
    func createProject(req:Request,
                       importUrl:String,
                       name:String) async throws -> Bool {
        let url = "https://gitee.com/swift-package-manager-mirror/projects"
        let response = try await req.client.post(URI(string: url)) { request in
            try request.content.encode([
                "project[import_url]":importUrl,
                "project[name]":name,
                "project[namespace_path]":"swift-package-manager-mirror",
                "project[path]":name,
                "project[description]":importUrl,
                "project[public]":"1",
                "language":"63",
            ])
            request.headers.cookie = cookies()
        }
        return response.status.code == 200
    }
    
    func cookies() -> HTTPCookies {
        var cookies = HTTPCookies()
        cookies["gitee-session-n"] = HTTPCookies.Value(string: session)
        return cookies
    }
}
