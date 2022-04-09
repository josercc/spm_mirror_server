
import Queues
import Vapor
struct WaitMirrorJob: MirrorAsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        context.logger.info("WaitMirrorJob: \(String(describing: payload.mirror.id)) \(String(describing: payload.mirror.mirror)) \(String(describing: payload.mirror.origin))")
        /// 获取数据库的镜像数据
        let mirror = payload.mirror
        /// 获取镜像是否制作完毕 制作完成则开启新的任务
        if mirror.isExit {
            let payload = MirrorJob.PayloadData(config: payload.config)
            /// 延时5秒开启新任务
            let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                sleep(5)
            }).get()
            try await context.application.queues.queue.dispatch(MirrorJob.self, payload)
            return
        }
        /// 创建 Github Api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        let repoPath = repoPath(from: mirror.mirror, host: "https://gitee.com/")
        /// 获取是否有制作镜像的Run状态
        let runStatus = try await githubApi.fetchRunStatus(repo: repoPath, in: context.application.client)
        if runStatus == .success {
            /// 开始成功的任务
            let payload = RunSuccessJob.PayloadData(config: payload.config, origin: mirror.origin)
            try await context.queue.dispatch(RunSuccessJob.self, payload)
            return
        }
        /// 如果处于等待和制作中 则等待30秒开始新的任务
        if runStatus == .queued || runStatus == .inProgress {
            let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                sleep(30)
            }).get()
            let payload = WaitMirrorJob.PayloadData(config: payload.config, mirror: mirror)
            try await context.queue.dispatch(WaitMirrorJob.self, payload)
            return
        }
        /// 如果处于失败状态 则增加等待次数
        if runStatus == .failure, let mirror = try await Mirror.find(payload.mirror.id, on: context.application.db) {
            /// 增加等待次数
            mirror.waitCount += 1
            /// 更新镜像数据
            try await mirror.update(on: context.application.db)
        }
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: mirror.origin)
        /// 创建 Github api
        /// 查询YML文件是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        /// 如果 YML存在就删除 YML文件
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        /// 延时 5 秒开启新任务
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(5)
        }).get()
        let payload = MirrorJob.PayloadData(config: payload.config)
        try await context.application.queues.queue.dispatch(MirrorJob.self, payload)
    }
}

extension WaitMirrorJob {
    struct PayloadData: JobPayload {
        let config: MirrorConfigration
        let mirror:Mirror
    }
}
