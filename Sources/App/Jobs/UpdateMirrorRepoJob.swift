//
//  UpdateMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues

/// 更新镜像的操作
struct UpdateMirrorRepoJob: AsyncJob {
    typealias Payload = Mirror
    func dequeue(_ context: QueueContext, _ payload: Mirror) async throws {
        guard let needUpdate = payload.needUpdate, needUpdate else {
            return
        }
        
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Mirror) async throws {
        let message = "\(payload.mirror) \(error.localizedDescription)"
        let wx = WeiXinWebHooks()
        wx.sendContent(message, in: context.application.client)
    }
}


extension UpdateMirrorRepoJob {
    
}
