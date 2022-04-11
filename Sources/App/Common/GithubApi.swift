//
//  GithubApi.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import Vapor

public struct GithubApi {
    let token:String
    let userAgent:String
    let repo:String
    let app:Application
    let host = "https://api.github.com"
    public init(app:Application, token:String, repo:String) throws {
        self.token = token
        self.userAgent = """
        Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15
        """
        self.repo = repo
        self.app = app
    }
    
    func addGithubAction(fileName:String,
                         content:String,
                         client:Client) async throws -> Bool {
        let url = "\(host)/repos/josercc/\(repo)/contents/.github/workflows/\(fileName)";
        let uri = URI(string: url)
        let response = try await client.put(uri, beforeSend: { request in
            request.headers = headers
            try request.content.encode([
                "message": "create \(fileName)",
                "content": try content.encodeBase64String()
            ], as: .json)
        })
        try response.printError(app: app, uri: uri, codes: [201])
        return response.status.code == 201
    }
    
    func isOrg(name:String, client:Client) async throws -> Bool {
        let uri = URI(string: "\(host)/users/\(name)")
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        try response.printError(app: app, uri: uri)
        let userInfo = try response.content.decode(GithubUserInfo.self)
        return userInfo.type == "Organization"
    }
    
    func ymlExit(file:String, in client:Client) async throws -> Bool {
        let uri = URI(string: "\(host)/repos/josercc/\(repo)/contents/.github/workflows/\(file)")
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        try response.printError(app: app, uri: uri, codes: [200,404])
        return response.status.code == 200
    }
    
    func deleteYml(fileName:String, in client:Client) async throws {
        let uri = URI(string: "\(host)/repos/josercc/\(repo)/contents/.github/workflows/\(fileName)")
        /// 读取文件信息
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        try response.printError(app: app, uri: uri)
        let content = try response.content.decode(GetFileContentResponse.self)
        /// 删除文件
        let deleteResponse = try await client.delete(uri, beforeSend: { request in
            request.headers = headers
            try request.content.encode([
                "sha": content.sha,
                "message":"remove \(fileName)"
            ])
        })
        try deleteResponse.printError(app: app, uri: uri)
    }
    
    func fetchRunStatus(repo:String, in client:Client) async throws -> RunStatus {
        let uri = URI(string: "\(host)/repos/josercc/sync2gitee/actions/runs?per_page=10")
        let response = try await client.get(uri, beforeSend: { request in
            request.headers = headers
            try request.query.encode([
                "per_page":"3"
            ])
        })
        try response.printError(app: app, uri: uri)
        let runResponse = try response.content.decode(FetchRunStatusResponse.self)
        guard let run = runResponse.workflow_runs.first(where: {$0.name.contains(repo)}) else {
            return .notExit
        }
        if run.status == "queued" {
            return .queued
        } else if run.status == "in_progress" {
            if let run_started_at = run.run_started_at,
                (Date().timeIntervalSince1970 - run_started_at.timeIntervalSince1970) > 1 * 60 * 60 {
                return .timeOut
            }
            return .inProgress
        } else if run.status == "completed", run.conclusion == "failure" {
            return .failure
        } else {
            return .success
        }
    }

    func getContents(name:String, repo:String, path:String) async throws -> [GetFileContentResponse] {
        let uri = URI(string: "\(host)/repos/\(name)/\(repo)/contents/\(path)")
        let response = try await app.client.get(uri, beforeSend: { request in
            request.headers = headers
        })
        try response.printError(app: app, uri: uri, codes: [200,404])
        if response.status.code == 404 {
            return []
        }
        guard let body = response.body else {
            throw Abort(.internalServerError, reason: "body is nil")
        }
        let object = try JSONSerialization.jsonObject(with: body, options: .fragmentsAllowed)
        if object is [Any] {
            return try response.content.decode([GetFileContentResponse].self)
        } else if object is [String:Any] {
            return [try response.content.decode(GetFileContentResponse.self)]
        } else {
            throw Abort(.internalServerError, reason: "unknown type")
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
    struct GetFileContentResponse: Content {
        let sha:String
        let name:String
        let content:String
    }
}

enum RunStatus {
    case queued
    case inProgress
    case success
    case failure
    case notExit
    case timeOut
}

struct FetchRunStatusResponse: Content {
    let workflow_runs:[Run]
}

extension FetchRunStatusResponse {
    struct Run: Content {
        let name:String
        let status:String
        let conclusion:String?
        let run_started_at:Date?
    }
}
