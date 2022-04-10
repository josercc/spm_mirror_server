
import Queues
import Vapor
struct WaitMirrorJob: MirrorAsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        
    }
}

extension WaitMirrorJob {
    struct PayloadData: JobPayload {
        let config: MirrorConfigration
        let mirror:Mirror
    }
}
