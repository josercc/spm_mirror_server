import Fluent
import FluentPostgresDriver
import Vapor
import QueuesRedisDriver

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

    
    

    try app.routes.register(collection: MirrorController())
    
    app.migrations.add(CreateMirror())
    app.migrations.add(CreateMirrorStack())
    app.migrations.add(CreateMirrorRequest())
    app.migrations.add(UpdateMirror001())
    app.migrations.add(UpdateMirror002())
    try app.autoMigrate().wait()
    
    app.logger.logLevel = .info
    // register routes
    try routes(app)
    let redisHost = Environment.get("REDIS_HOST") ?? "127.0.0.1"
    app.redis.configuration = try RedisConfiguration(hostname: redisHost)
    try app.queues.use(.redis(url: "redis://\(redisHost):6379"))
    app.queues.add(MirrorJob())
    app.queues.add(StartMirrorJob())
    app.queues.add(UpdateMirrorJob())
    app.queues.add(WaitMirrorJob())
    try app.queues.startInProcessJobs(on: .default)

    /// 每天下午12点开启任务
    app.queues.schedule(TimeJob())
    .daily()
    .at(.noon)
    /// 获取配置文件 MirrorConfigration
    let config = try MirrorConfigration()
    /// 开启镜像任务
    let job = MirrorJob.PayloadData(config: config)
    /// 开启任务
    Task {
        let isRunning = await mirrorJobStatus.isRunning
        guard !isRunning else {
            app.logger.info("当前存在其他镜像任务，启动镜像任务失败")
            return
        }
        await mirrorJobStatus.start()
        do {
            try await app.queues.queue.dispatch(MirrorJob.self, job)
        } catch (let e) {
            /// 创建weixin Hook
            let hook = WeiXinWebHooks(app: app, url: config.wxHookUrl)
            hook.sendContent(e.localizedDescription, in: app.client)
        }
        await mirrorJobStatus.stop()
    }
}


