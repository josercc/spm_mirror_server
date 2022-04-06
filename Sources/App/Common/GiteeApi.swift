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
    
    func checkRepoExit(repo:String, in client:Client) async throws -> Bool {
        let uri = URI(string: "https://gitee.com/api/v5/search/repositories?access_token=\(token)&q=\(repo)")
        let response = try await client.get(uri)
        let repos = try response.content.decode([Repo].self)
        try response.printError(app: app, uri: uri)
        return repos.count > 0
    }
}

struct Repo: Codable {
    
}
