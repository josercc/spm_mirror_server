
import Queues
import Vapor
struct WaitMirrorJob: MirrorAsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        /// 获取数据库的镜像数据
        let mirror = payload.mirror
        /// 获取镜像是否制作完毕 制作完成则开启新的任务
        guard mirror.isExit else {
            let payload = MirrorJob.PayloadData(config: payload.config)
            /// 延时5秒开启新任务
            let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                sleep(5)
            }).get()
            try await context.application.queues.queue.dispatch(MirrorJob.self, payload)
            return
        }
        /// 创建 GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        /// 查询镜像仓库是否存在
        let repoExit = try await giteeApi.checkRepoExit(repo: mirror.mirror, in: context.application.client)
        /// 如果镜像仓库不存在开启新的 MirrorJob
        if !repoExit {
            let payload = MirrorJob.PayloadData(config: payload.config)
            /// 延时 30 秒开启新任务
            let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                sleep(30)
            }).get()
            try await context.application.queues.queue.dispatch(MirrorJob.self, payload)
            return
        }
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: mirror.origin)
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 查询YML文件是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        /// 如果 YML存在就删除 YML文件
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        /// 更新数据库是否存在的状态
        mirror.isExit = true
        /// 更新数据库
        try await mirror.update(on: context.application.db)
        /// 延时 30 秒开启新任务
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(30)
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