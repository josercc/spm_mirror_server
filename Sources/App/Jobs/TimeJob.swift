import Queues
struct TimeJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let isRunning = await mirrorJobStatus.isRunning
        guard !isRunning else {
            context.logger.info("当前存在运行的镜像任务 定时任务启动失败")
            return
        }
        await mirrorJobStatus.start()
       /// 开启任务
        let configration = try MirrorConfigration()
        let job = MirrorJob.PayloadData(config: configration)
        try await context.application.queues.queue.dispatch(MirrorJob.self, job)
        await mirrorJobStatus.stop()
    }
}