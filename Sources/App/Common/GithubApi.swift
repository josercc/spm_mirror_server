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
            throw Abort(.systemError)
        }
        self.token = token
        self.userAgent = """
        Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15
        """
        guard let repo = Environment.get("GITHUB_REPO") else {
            print("GITHUB_REPO不存在")
            throw Abort(.systemError)
        }
        self.repo = repo
    }
    
    func addGithubAction(fileName:String,
                         content:String,
                         req:Request) async throws -> Bool {
        let url = "https://api.github.com/repos/josercc/\(repo)/contents/.github/workflows/\(fileName).yml";
        let uri = URI(string: url)
        req.logger.debug("正在创建\(fileName).yml文件")
        let response = try await req.client.put(uri, beforeSend: { request in
            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(token)")
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
        print(response.status.code)
        return response.status.code == 201
    }
    
    func isOrg(name:String, req:Request) async throws -> Bool {
        let uri = URI(string: "https://api.github.com/users/\(name)")
        req.logger.debug("正在查询\(name)组织信息")
        let response = try await req.client.get(uri, beforeSend: { request in
            var headers = HTTPHeaders()
            headers.add(name: .userAgent,
                        value: userAgent)
            request.headers = headers
        })
        req.logger.debugResponse(response: response)
        let userInfo = try response.content.decode(GithubUserInfo.self)
        return userInfo.type == "Organization"
    }
}
