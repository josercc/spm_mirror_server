@testable import App
import XCTVapor
import Queues

final class AppTests: XCTestCase {
    func testHelloWorld() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        let semphore = DispatchSemaphore(value: 0)
        Task {
            let payload = MirrorJob.Payload(config: try MirrorConfigration())
            let job = MirrorJob()
            try await job.create(app.queues.queue.context, payload, "https://github.com/mklbtz/finch")
            semphore.signal()
        }
        semphore.wait()
    }
}
