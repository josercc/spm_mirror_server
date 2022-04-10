import Queues
import FluentKit
import Vapor
struct RunSuccessJob: MirrorAsyncJob {
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("制作镜像成功:->>\(payload.origin)")
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: payload.origin)
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 检测YML文件是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        /// 如果 YML存在就删除 YML文件
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        /// 查询镜像队列存在
        if let stack = try await MirrorStack.query(on: context.application.db).filter(\.$url == payload.origin).first() {
            /// 删除镜像队列
            try await stack.delete(on: context.application.db)
        }
        /// 查询镜像
        if let mirror = try await Mirror.query(on: context.application.db).filter(\.$origin == payload.origin).filter(\.$isExit == false).first() {
            /// 更新是否存在
            mirror.isExit = true
            mirror.needUpdate = false
            mirror.lastMittorDate = Date().timeIntervalSince1970
            try await mirror.update(on: context.application.db)            
        }
        /// 延时 10 秒
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(10)
        }).get()
        /// 开启新的队列
        let job = MirrorJob.PayloadData(config: payload.config)
        try await context.queue.dispatch(MirrorJob.self, job)
    }

    typealias Payload = PayloadData
}

extension RunSuccessJob {
    struct PayloadData: JobPayload {
        let config: MirrorConfigration
        let origin:String
    }
}