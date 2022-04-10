import Vapor
import Queues
import FluentKit
struct MirrorJob: MirrorAsyncJob {
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("开启自动任务->>")
        /// 查询是否还有未完成的任务
        let waitMirror = try await Mirror.query(on: context.application.db).filter(\.$isExit == false).first()       
        if let waitMirror = waitMirror {
            context.logger.info("查询还没有制作完成->>\(waitMirror.origin)")
            let mirrorJob = WaitMirrorJob.PayloadData(config: payload.config, mirror: waitMirror)
            try await context.queue.dispatch(WaitMirrorJob.self, mirrorJob)
            return
        }
        /// 查询是否还有没有创建镜像的队列
        let mirrorStack = try await MirrorStack.query(on: context.application.db).sort(\.$create, .descending).first()
        /// 如果镜像队列存在则开启镜像任务
        if let mirrorStack = mirrorStack {
            context.logger.info("查询还有未制作的镜像->>\(mirrorStack.url)")
            let mirrorJob = MirrorJobData.init(mirrorStack: mirrorStack, config: payload.config, mirrorOrg: nil)
            try await context.application.queues.queue.dispatch(StartMirrorJob.self, mirrorJob)
            return
        }
        /// 获取需要进行更新的镜像
        let needUpdateMirror = try await Mirror.query(on: context.application.db).filter(\.$needUpdate == true).first()
        /// 如果需要进行更新的镜像存在则开启更新任务
        if let needUpdateMirror = needUpdateMirror {
            context.logger.info("查询还有需要更新的镜像->>\(needUpdateMirror.origin)")
            let mirrorJob = UpdateMirrorJob.PayloadData(config: payload.config, mirror: needUpdateMirror)
            try await context.application.queues.queue.dispatch(UpdateMirrorJob.self, mirrorJob)
            return
        }
        /// 获取现在时间的时间戳
        let now = Date().timeIntervalSince1970
        /// 获取一周之前的时间戳
        let weekAgo = now - 604800
        /// 获取所有请求镜像次数超过 1000 次的仓库 并且最后更新时间小于当前时间一周的仓库
        let needUpdateMirrors = try await Mirror.query(on: context.application.db).filter(\.$requestMirrorCount >= 1000).filter(\.$lastMittorDate <= weekAgo).all()
        guard needUpdateMirrors.count > 0 else {
            context.logger.info("没有需要更新的镜像->>")
            return
        }
        /// 将镜像的最后更新时间小于一周的更新需要更新
        for mirror in needUpdateMirrors {
            mirror.needUpdate = true
            try await mirror.save(on: context.application.db)
        }
        /// 延时5秒再次执行
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(5)
        }).get()
        /// 开启新的 MirrorJob 任务
        let job = MirrorJob.PayloadData(config: payload.config)
        try await context.application.queues.queue.dispatch(MirrorJob.self, job)
    }
    typealias Payload = PayloadData
}


extension MirrorJob {
    func wait(_ context: QueueContext, _ payload: PayloadData, mirror:Mirror) async throws {
        context.logger.info("WaitMirrorJob: \(String(describing: mirror.id)) \(String(describing: mirror.mirror)) \(String(describing: mirror.origin))")
        /// 获取镜像是否制作完毕 制作完成则开启新的任务
        if mirror.isExit {
            context.logger.info("镜像已经存在开启新任务")
            try await start(context, payload)
            return
        }
        /// 查询 Gitee镜像是否存在
        if try await checkMirrorRepoExit(context, payload, mirror.origin, mirror.mirror) {
            try await success(context, payload, mirror.origin)
            return
        }
        /// 创建 Github Api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        let repoPath = repoPath(from: mirror.mirror, host: "https://gitee.com/")
        /// 获取是否有制作镜像的Run状态
        let runStatus = try await githubApi.fetchRunStatus(repo: repoPath, in: context.application.client)
        if runStatus == .success {
            try await success(context, payload, mirror.origin)
            return
        }
        /// 如果处于等待和制作中 则等待30秒开始新的任务
        if runStatus == .queued || runStatus == .inProgress {
            context.logger.info("镜像正在制作中,延时30秒开启新任务")
            let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                sleep(30)
            }).get()
            let payload = WaitMirrorJob.PayloadData(config: payload.config, mirror: mirror)
            try await context.queue.dispatch(WaitMirrorJob.self, payload)
            return
        }
        context.logger.info("镜像制作失败或者未开始,开始重试任务")
        /// 如果处于失败状态 则增加等待次数
        if runStatus == .failure, let mirror = try await Mirror.find(payload.mirror.id, on: context.application.db) {
            /// 增加等待次数
            mirror.waitCount += 1
            /// 如果等待次数大于5次则微信通知
            if mirror.waitCount > 5 {
                /// 发送微信通知
                let weixinHost = WeiXinWebHooks(app: context.application, url: payload.config.wxHookUrl)
                weixinHost.sendContent("\(payload.mirror.origin)镜像制作失败,请检查镜像是否正常制作", in: context.application.client)
            }
            /// 更新镜像数据
            try await mirror.update(on: context.application.db)
        }
        guard let dst = repoOriginPath(from: mirror.mirror, host: "https://gitee.com/") else {
            throw Abort(.custom(code: 10000, reasonPhrase: "获取镜像组织名称失败"))
        }
        /// 开启创建YML任务
        let payload = CreateYMLJob.PayloadData(config: payload.config, origin: mirror.origin, dst: dst)
        try await context.queue.dispatch(CreateYMLJob.self, payload)
        /// 延时5秒
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(5)
        }).get()
        /// 开启创建镜像任务
        let payload2 = MirrorJob.PayloadData(config: payload.config)
        try await context.queue.dispatch(MirrorJob.self, payload2)
    }
}

extension MirrorJob {
    /// 开始新任务
    func start(_ context:QueueContext, _ payload:PayloadData, _ sleepTime:UInt32 = 5) async throws {
        context.logger.info("延时\(sleepTime)秒")
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(sleepTime)
        }).get()
        /// 开启任务
        let payload = MirrorJob.PayloadData(config: payload.config)
        try await context.queue.dispatch(MirrorJob.self, payload)
    }
}

extension MirrorJob {
    func success(_ context:QueueContext, _ payload:PayloadData, _ origin:String) async throws {
        context.logger.info("制作镜像成功:->>\(origin)")
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: origin)
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 检测YML文件是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        /// 如果 YML存在就删除 YML文件
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        for stack in try await MirrorStack.query(on: context.application.db).filter(\.$url == origin).all() {
            try await stack.delete(on: context.application.db)
        }
        /// 查询镜像
        for mirror in try await Mirror.query(on: context.application.db).filter(\.$origin == origin).all() {
            /// 更新是否存在
            mirror.isExit = true
            mirror.needUpdate = false
            mirror.lastMittorDate = Date().timeIntervalSince1970
            try await mirror.update(on: context.application.db)            
        }
        try await start(context, payload)
    }
}


extension MirrorJob {
    struct PayloadData: JobPayload {
        var config: MirrorConfigration        
    }
}

/// 管理镜像任务状态
actor MirrorJobStatus {
    var isRunning: Bool = false
    func start() {
        isRunning = true
    }
    func stop() {
        isRunning = false
    }
}

let mirrorJobStatus = MirrorJobStatus()