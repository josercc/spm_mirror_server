import Vapor
import Queues
import FluentKit
struct MirrorJob: MirrorAsyncJob {
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("MirrorJob:")
       /// 查询是否还有未完成的任务并且重试次数还没有超过60次
        let waitMirror = try await Mirror.query(on: context.application.db).filter(\.$isExit == false).filter(\.$waitCount <= 60).first()
        /// 如果有未完成的任务则开启未完成任务
        if let waitMirror = waitMirror {
            let mirrorJob = WaitMirrorJob.PayloadData(config: payload.config, mirror: waitMirror)
            try await context.application.queues.queue.dispatch(WaitMirrorJob.self, mirrorJob)
            return
        }
        /// 查询是否还有没有创建镜像的队列
        let mirrorStack = try await MirrorStack.query(on: context.application.db).sort(\.$create, .descending).first()
        /// 如果镜像队列存在则开启镜像任务
        if let mirrorStack = mirrorStack {
            let mirrorJob = MirrorJobData.init(mirrorStack: mirrorStack, config: payload.config, mirrorOrg: nil)
            try await context.application.queues.queue.dispatch(StartMirrorJob.self, mirrorJob)
            return
        }
        /// 获取需要进行更新的镜像
        let needUpdateMirror = try await Mirror.query(on: context.application.db).filter(\.$needUpdate == true).first()
        /// 如果需要进行更新的镜像存在则开启更新任务
        if let needUpdateMirror = needUpdateMirror {
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