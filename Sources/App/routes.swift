import Fluent
import Vapor
import FluentKit

func routes(_ app: Application) throws {
    let autoMirrorJob = try AutoMirrorJob(app: app)
    autoMirrorJob.start()
}

