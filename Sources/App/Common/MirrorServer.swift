//
//  MirrorServer.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import Vapor

class MirrorServerManager {
    let org:String = "spm_mirror"
    let repo:String = "server_config"
    let path:String = "mirror_servers.json"
    let req:Request
    let api:GiteeApi
    
    var sha:String = ""
    
    init(req:Request, api:GiteeApi) {
        self.req = req
        self.api = api
    }
    /// 获取服务器配置的镜像数据
    func servers() async throws -> [MirrorServer] {
        req.logger.debug("正在获取镜像配置文件")
        let content = try await api.getPathContent(use: req,
                                                   owner: org,
                                                   repo: repo,
                                                   path: path)
        sha = content.sha
        let base64Decode = try content.content.decodeBase64String()
        guard let data = base64Decode.data(using: .utf8) else {
            throw Abort(.systemError)
        }
        return try JSONDecoder().decode([MirrorServer].self, from: data)
    }
}
