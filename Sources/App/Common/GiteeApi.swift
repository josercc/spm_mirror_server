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
    final let githubToken:String
    init() throws {
        guard let token = Environment.get("GITEE_TOKEN") else {
            throw Abort(.tokenNotExit)
        }
        self.token = token
        guard let githubToken = Environment.get("GITHUB_TOKEN") else {
            throw Abort(.custom(code: 10010, reasonPhrase: "GITHUB_TOKEN 不存在"))
        }
        self.githubToken = githubToken
    }
    
    func checkFetck(name:String, req:Request) async throws -> CheckFetch {
        let url = "https://gitee.com/swift-package-manager-mirror/\(name)/check_fetch"
        print("get \(url)")
        let response = try await req.client.get(URI(string: url))
        guard let body = response.body,
              let _ = try? JSONSerialization.jsonObject(with: body,
                                                        options: .fragmentsAllowed) else {
            return CheckFetch(inFetch: false, emptyRepo: true)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try response.content.decode(CheckFetch.self, using: decoder)
    }
    
    func getPathContent(use req:Request,
                        owner:String,
                        repo:String,
                        path:String) async throws -> PathContentResponse {
        let uri = URI(string: "\(host)/repos/\(owner)/\(repo)/contents/\(path)?access_token=\(token)")
        print(uri)
        let response = try await req.client.get(uri)
        if let body = response.body {
            print(String(buffer: body))
        }
        let content = try response.content.decode(PathContentResponse.self)
        return content
    }
        
    func updateContent(content:String,
                       req:Request,
                       repoPath:String,
                       path:String,
                       owner:String,
                       sha:String,
                       message:String) async throws -> Bool {
        let url = "https://gitee.com/api/v5/repos/\(owner)/\(repoPath)/contents/\(path)"
        print(url)
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
    
    func addGithubAction(fileName:String, req:Request, content:String) async throws {
        let url = "https://api.github.com/repos/josercc/sync2gitee/contents/.github/workflows/\(fileName).yml";
        let uri = URI(string: url)
        print(uri)
        let response = try await req.client.put(uri, beforeSend: { request in
            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(githubToken)")
            headers.add(name: .userAgent, value: userAgent)
            request.headers = headers
            try request.content.encode([
                "message": "create \(fileName)",
                "content": try content.encodeBase64String()
            ], as: .json)
        })
        if let body = response.body {
            print(String(buffer: body))
        }
    }
}
