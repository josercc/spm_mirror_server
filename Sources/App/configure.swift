import Fluent
import FluentPostgresDriver
import Vapor

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
    
    
    /// 开启自动任务
    let autoMirrorJob = try AutoMirrorJob(app: app)
    autoMirrorJob.start()

}
