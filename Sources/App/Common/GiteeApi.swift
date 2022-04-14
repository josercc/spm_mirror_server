//
//  GiteeApi.swift
//  
//
//  Created by admin on 2022/3/19.
//

import Foundation
import Vapor

public class GiteeApi {
    final let host = "https://gitee.com/api/v5"
    final let token:String
    let app:Application
    public init(app:Application, token:String) throws {
        self.token = token
        self.app = app
    }

    func getUserOrg(client:Client) async throws -> [UserOrgModel] {
        let path = "/user/orgs?access_token=\(token)&page=1&per_page=100&admin=true"
        let uri = URI(string: host + path)
        let response = try await client.get(uri)
        try response.printError(app: app, uri: uri)
        return try response.content.decode([UserOrgModel].self)
    }
    
    func createOrg(client:Client, name:String) async throws  {
        let path = host + "/users/organization"
        let uri = URI(string: path)
        let response = try await client.post(URI(string: path), beforeSend: { request in
            try request.content.encode([
                "access_token":token,
                "name":name,
                "org":name
            ])
        })
        try response.printError(app: app, uri: uri, codes: [201])
    }
    
    func checkRepoExit(owner:String, repo:String, in client:Client) async throws -> [Repo] {
        let uri = URI(string: "https://gitee.com/api/v5/search/repositories?access_token=\(token)&q=\(repo)&owner=\(owner)")
        let response = try await client.get(uri)
        try response.printError(app: app, uri: uri)
        let repos = try response.content.decode([Repo].self, using: JSONDecoder.custom(keys: .convertFromSnakeCase))
        let repoPath = "\(owner)/\(repo)"
        let filters = repos.filter { repo in
            /// 因为不区分大小写，所以需要转换一下
            return repo.fullName.lowercased() == repoPath.lowercased()
        }
        return filters
    }

    /// 检查组织是否存在
    func checkOrgExit(org:String, in client:Client) async throws -> Bool {
        /// 获取所有组织
        let orgs = try await getUserOrg(client: client)
        return orgs.contains(where: { $0.name == org })
    }

    func getFileContent(name:String, repo:String, path:String = "", in client:Client) async throws -> [GithubApi.GetFileContentResponse] {
        let uri = URI(string: "https://gitee.com/api/v5/repos/\(name)/\(repo)/contents/\(path)?access_token=\(token)")
        let response = try await client.get(uri)
        try response.printError(app: app, uri: uri, codes: [200,404])
        if response.status.code == 404 {
            return []
        }
        guard let body = response.body else {
            throw Abort(.badRequest, reason: "body is nil")
        }
        let data = try JSONSerialization.jsonObject(with: body)
        if data is [Any] {
            return try response.content.decode([GithubApi.GetFileContentResponse].self)
        } else if data is [String:Any] {
            return [try response.content.decode(GithubApi.GetFileContentResponse.self)]
        }
        return []
    }

    /// 删除一个仓库
    func deleteRepo(name:String, repo:String, in client:Client) async throws {
        /// https://gitee.com/api/v5/repos/{owner}/{repo}
        let uri = URI(string: "\(host)/repos/\(name)/\(repo)?access_token=\(token)")
        let response = try await client.delete(uri)
        try response.printError(app: app, uri: uri, codes: [204,404])
    }

    func canImport(name:String, repo:String, in client:Client) async throws -> Bool {
        let uri = URI(string: "https://gitee.com/projects/check_project_duplicate?import_url=https%3A%2F%2Fgithub.com%2F\(name)%2F\(repo)")
        let response = try await client.get(uri)
        try response.printError(app: app, uri: uri)
        let data = try response.content.decode(CanImportResponse.self, using: JSONDecoder.custom(keys: .convertFromSnakeCase))
        return !data.isDuplicate
    }

    /// 获取一个组织目前的项目数量
    func getOrgProjectsCount(org:String, in client:Client) async throws -> Int {
        let uri = URI(string: "https://gitee.com/api/v5/orgs/\(org)?access_token=\(token)")
        let response = try await client.get(uri)
        try response.printError(app: app, uri: uri)
        let data = try response.content.decode(Project.self, using: JSONDecoder.custom(keys: .convertFromSnakeCase))
        let count = data.publicRepos + data.privateRepos
        return count
    }
}

struct Repo: Codable {
    let fullName:String
}

struct CanImportResponse: Content {
    let isDuplicate:Bool
}

struct Project: Content {
    /// public_repos
    let publicRepos:Int
    /// private_repos
    let privateRepos:Int
}
