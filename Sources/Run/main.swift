import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()

/// 开启自动任务
let autoMirrorJob = try AutoMirrorJob(app: app)
autoMirrorJob.start()
