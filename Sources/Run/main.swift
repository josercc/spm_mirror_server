import App
import Vapor


var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer {
    let config = try MirrorConfigration()
    WeiXinWebHooks.sendContent("服务器已经停止，请马上重启！", app, config)
    app.shutdown()
}
try configure(app)
try app.run()

