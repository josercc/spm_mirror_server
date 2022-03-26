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
        guard let token = ProcessInfo.processInfo.environment["GITEE_TOKEN"] else {
            throw Abort(.tokenNotExit)
        }
        self.token = token
        guard let session = ProcessInfo.processInfo.environment["GITEE_SESSION"] else {
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
                        path:String) async throws -> String {
        let uri = URI(string: "\(host)/repos/\(owner)/\(repo)/contents/\(path)?access_token=\(token)")
        let response = try await req.client.get(uri)
        let content = try response.content.decode(PathContentResponse.self)
        guard let data = Data(base64Encoded: content.content),
                let fileContent = String(data: data, encoding: .utf8) else {
            throw Abort(.getPathContentError)
        }
        return fileContent
    }
}
