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
            throw Abort(.tokenNotExit)
        }
        self.token = token
    }

    func getUserOrg(req:Request) async throws -> [UserOrgModel] {
        req.logger.debug("正在获取用户的组织信息")
        let path = "/user/orgs?access_token=\(token)&page=1&per_page=100&admin=true"
        let uri = URI(string: host + path)
        let response = try await req.client.get(uri)
        return try response.content.decode([UserOrgModel].self)
    }
    
    func createOrg(req:Request, name:String) async throws {
        req.logger.debug("正在创建组织:\(name)")
        let path = host + "/users/organization"
        let response = try await req.client.post(URI(string: path), beforeSend: { request in
            try request.content.encode([
                "access_token":token,
                "name":name,
                "org":name
            ])
        })
        guard response.status.code == 200 else {
            req.logger.debug("创建组织\(name)失败")
            throw Abort(.custom(code: 1000, reasonPhrase: "创建组织\(name)失败"))
        }
    }
}
