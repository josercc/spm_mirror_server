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
    init() throws {
        guard let token = Environment.get("GITEE_TOKEN") else {
            throw Abort(.expectationFailed)
        }
        self.token = token
    }

    func getUserOrg(client:Client) async throws -> [UserOrgModel] {
        let path = "/user/orgs?access_token=\(token)&page=1&per_page=100&admin=true"
        let uri = URI(string: host + path)
        let response = try await client.get(uri)
        return try response.content.decode([UserOrgModel].self)
    }
    
    func createOrg(client:Client, name:String) async throws {
        let path = host + "/users/organization"
        let response = try await client.post(URI(string: path), beforeSend: { request in
            try request.content.encode([
                "access_token":token,
                "name":name,
                "org":name
            ])
        })
        guard response.status.code == 200 else {
            throw Abort(.custom(code: 1000, reasonPhrase: "创建组织\(name)失败"))
        }
    }
    
    func checkRepoExit(url:String, in client:Client) async throws -> Bool {
        let uri = URI(string: url)
        let response = try await client.get(uri)
        return response.status.code == 200
    }
}
