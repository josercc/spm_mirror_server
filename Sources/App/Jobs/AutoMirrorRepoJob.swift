//
//  AutoMirrorRepoJob.swift
//  
//
//  Created by king on 2022/4/5.
//

import Foundation
import Queues

struct MirrorJobData: Codable {
    let url:String
}


struct AutoMirrorRepoJob: AsyncJob {
    typealias Payload = MirrorJobData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        
    }
}
