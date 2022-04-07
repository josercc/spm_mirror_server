import Queues

protocol MirrorAsyncJob: AsyncJob {
    associatedtype Payload = JobPayload
}

extension MirrorAsyncJob {
    func error(_ context: QueueContext, _ error: Error, _ payload: JobPayload) async throws {
        /// 创建 Weixin Hook
        let weixinHook = try WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
        /// 发送错误信息
        weixinHook.sendContent(error.localizedDescription, in: context.application.client)
    }
}

protocol JobPayload: Codable {
    var config:MirrorConfigration { get }
}