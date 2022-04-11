import Fluent
import FluentPostgresDriver
import Vapor
import QueuesRedisDriver
import Redis

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
    guard let redisHost = Environment.get("REDIS_HOST") else {
        throw Abort(.custom(code: 10000, reasonPhrase: "REDIS_HOST environment variable not set"))
    }
    print("redisHost: \(redisHost)")
    
    app.redis.configuration = try RedisConfiguration(hostname: redisHost, pool: .init(initialConnectionBackoffDelay: .seconds(30), connectionRetryTimeout: .seconds(30)))
    try app.queues.use(.redis(url: "redis://\(redisHost):6379"))
    app.queues.add(MirrorJob())
    try app.queues.startInProcessJobs(on: .default)

    /// 每天下午12点开启任务
    app.queues.schedule(TimeJob())
    .daily()
    .at(.noon)
}


