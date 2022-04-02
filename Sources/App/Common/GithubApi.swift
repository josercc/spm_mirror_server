//
//  GithubApi.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import Vapor

struct GithubApi {
    let token:String
    let userAgent:String
    let repo:String
    init() throws {
        guard let token = Environment.get("GITHUB_TOKEN") else {
            print("GITHUB_TOKEN 不存在")
            throw Abort(.expectationFailed)
        }
        self.token = token
        self.userAgent = """
        Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15
        """
        guard let repo = Environment.get("GITHUB_REPO") else {
            print("GITHUB_REPO不存在")
            throw Abort(.expectationFailed)
        }
        self.repo = repo
    }
    
    func addGithubAction(fileName:String,
                         content:String,
                         client:Client) async throws -> Bool {
        let url = "https://api.github.com/repos/josercc/\(repo)/contents/.github/workflows/\(fileName)";
        let uri = URI(string: url)
        let response = try await client.put(uri, beforeSend: { request in
            request.headers = headers
            try request.content.encode([
                "message": "create \(fileName)",
                "content": try content.encodeBase64String()
            ], as: .json)
        })
        if let body = response.body {
            print(String(buffer: body))
        }
        print(response.status.code)
        return response.status.code == 201
    }
    
    func isOrg(name:String, client:Client) async throws -> Bool {
        let uri = URI(string: "https://api.github.com/users/\(name)")
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        let userInfo = try response.content.decode(GithubUserInfo.self)
        return userInfo.type == "Organization"
    }
    
    func ymlExit(file:String, in client:Client) async throws -> Bool {
        let uri = URI(string: "https://api.github.com/repos/josercc/\(repo)/contents/\(file)")
        let response = try await client.get(uri)
        return response.status.code == 200
    }
    
    func deleteYml(fileName:String, in client:Client) async throws {
        let uri = URI(string: "https://api.github.com/repos/josercc/\(repo)/contents/.github/workflows/\(fileName)")
        /// 读取文件信息
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        let content = try response.content.decode(GetFileContentResponse.self)
        /// 删除文件
        let deleteResponse = try await client.delete(uri, beforeSend: { request in
            request.headers = headers
            try request.content.encode([
                "sha": content.sha,
                "message":"remove \(fileName)"
            ])
        })
        if deleteResponse.status.code != 200, let body = deleteResponse.body {
            throw Abort(.custom(code: deleteResponse.status.code,
                                reasonPhrase: String(buffer: body)))
        }
    }
    
    var headers:HTTPHeaders {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .accept, value: " application/vnd.github.v3+json")
        headers.add(name: .authorization, value: "Bearer \(token)")
        headers.add(name: .userAgent, value: userAgent)
        return headers
    }
}

extension GithubApi {
    struct GetFileContentResponse: Codable {
        let sha:String
    }
}
