
import Queues
import Vapor
/// 创建 YML任务
struct CreateYMLJob: MirrorAsyncJob {
    typealias Payload = PayloadData
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("开始创建YML文件:->>\(payload.origin)")
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 查询YML Run状态
        let runStatus = try await githubApi.fetchRunStatus(repo: payload.config.githubRepo, in: context.application.client)
        /// 如果处于等待和制作中 则开启新的任务
        if runStatus == .queued || runStatus == .inProgress {
            context.logger.info("YML已经正在制作中,延时30秒开启新任务")
            let payload = MirrorJob.PayloadData(config: payload.config)
            try await context.queue.dispatch(MirrorJob.self, payload)
            return
        }
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: payload.origin)
        /// 如果 YML存在就删除 YML文件
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        guard let src = repoOriginPath(from: payload.origin) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(payload.origin) 获取组织失败"))
        }
        /// 检测是否是组织
        let isOrg = try await githubApi.isOrg(name: payload.config.githubRepo, client: context.application.client)
        guard let repo = repoNamePath(from: payload.origin) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(payload.origin) 获取项目失败"))
        }
        /// 创建 YML 内容
        let ymlContent = actionContent(src: src, dst: payload.dst, isOrg: isOrg, repo: repo)
        /// 创建 YML文件
        guard try await githubApi.addGithubAction(fileName: ymlPath, content: ymlContent, client: context.application.client) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(payload.origin) 创建YML文件失败"))
        }
        context.logger.info("创建YML文件成功:->>\(payload.origin) 延时30秒开启新任务")
        /// 延时30秒
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(30)
        }).get()
    }
}

extension CreateYMLJob {
    struct PayloadData: JobPayload {
        let config: MirrorConfigration
        let origin: String
        let dst:String
    }
}