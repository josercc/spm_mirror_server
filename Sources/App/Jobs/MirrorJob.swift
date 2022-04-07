import Vapor
import Queues
struct MirrorJob: AsyncJob {
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
       
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: PayloadData) async throws {
        /// 创建 Weixin Hook
        let weixinHook = try WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        /// 发送错误信息
        weixinHook.sendContent(error.localizedDescription, in: context.application.client)
    }
    typealias Payload = PayloadData
}

extension MirrorJob {
    struct PayloadData: Codable {
        let config:MirrorConfigration
    }
}