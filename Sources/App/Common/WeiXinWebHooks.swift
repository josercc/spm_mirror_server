//
//  WeiXinWebHooks.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import Vapor

/// 负责发送错误日志给微信 能够及时处理问题
public struct WeiXinWebHooks {
    /// 微信接收的 WebHook地址
    let url:String
    let app:Application
    public init(app:Application, url:String) {
        self.url = url
        self.app = app
    }
    /// 给微信机器人发送消息
    /// - Parameters:
    ///   - content: 发送内容
    ///   - client: 发送的链接终端
    func sendContent(_ content:String, in client:Client) {
        Task {
            let uri = URI(string: url)
            let response = try await client.post(uri, beforeSend: { request in
                let model:WeiXinWebHookContent = .init(msgtype: "text", text: .init(content: content))
                let data = try JSONEncoder().encode(model)
                request.body = ByteBuffer(data: data)
            })
            try response.printError(app: app, uri: uri, codes: [])
        }
    }

    public static func sendContent(_ content:String, _ app:Application, _ config:MirrorConfigration) {
        let wxApi = WeiXinWebHooks(app: app, url: config.wxHookUrl)
        wxApi.sendContent(content, in: app.client)
    }
}

struct WeiXinWebHookContent: Codable {
    let msgtype:String
    let text:TextContent
}

extension WeiXinWebHookContent {
    struct TextContent: Codable {
        let content:String
    }
}
