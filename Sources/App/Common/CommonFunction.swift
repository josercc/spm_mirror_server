//
//  CommonFunction.swift
//  
//
//  Created by admin on 2022/3/14.
//

import Foundation
import Vapor

func mirrData(from url:String) -> String {
    return url.replacingOccurrences(of: "https://github.com/", with: "")
        .replacingOccurrences(of: ".git", with: "")
}

func checkIsExit(path:String, isDir:Bool) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: path,
                                          isDirectory: &isDirectory)
    && isDir == isDirectory.boolValue
}

//struct CheckFetch: Content {
//    let inFetch:Bool
//    let emptyRepo:Bool
//}
//
//func createRepo(repo:String, req:Request) async throws {
//    print("post \(giteeApi)/orgs/swift-package-manager-mirror/repos")
//    let response = try await req.client.post("\(giteeApi)/orgs/swift-package-manager-mirror/repos", beforeSend: { request in
//        try request.content.encode([
//            "access_token": accessToken,
//            "name": repo,
//            "public": "1",
//            "path": repo
//        ])
//    })
//    guard response.status.code == 201 else {
//        throw Abort(.custom(code: response.status.code, reasonPhrase: "创建 Gitee 仓库失败"))
//    }
//}
//
func mirrorRepo(repo:String) -> String {
    return "https://gitee.com/swift-package-manager-mirror/\(repo)"
}
//
//func createProject(req:Request,
//                   importUrl:String,
//                   name:String) async throws -> Bool {
//    let url = "https://gitee.com/swift-package-manager-mirror/projects"
//    let response = try await req.client.post("\(url)") { request in
//        try request.content.encode([
//            "project[import_url]":importUrl,
//            "project[name]":name,
//            "project[namespace_path]":"swift-package-manager-mirror",
//            "project[path]":name,
//            "project[description]":importUrl,
//            "project[public]":"1",
//            "language":"63",
//        ])
//        request.headers.cookie = HTTPCookies(dictionaryLiteral: ("gitee-session-n","QlFoZTN4eEhlUExraHZXK2dUYnpYMG9UNy92WEdkaHFtQ2h0T1B2aUxDQ1MwU3hNeFNpckhXczVyWTFqUW5RVGtHRCtzVlkzbDYwNVdxRkpONTVncTlnRUpYUGhYOTIrNUVvWlBtdGl3cjBLbjkwR3hoOHovcFhKRGJuclh3TXdxc3FKU1hza0RsQTBZWmo1UGFXU2FUUHJPN1JLSkhEcUMwd3I3QmdsMFlqcU1ncWcwUS94K1o5c2o5aFdEaDF3OWo4SldRUzhlQjMzbHdIZ2g1dmlnc1J4RGZ6bXZ1bW5aZkdUSk1MblE5cDF4SFhnK1l1aVkxcjdTejBMWUNWckl2Ym56biszMzFWcEorS0ViYjhYNEczL2l4RVpKRGVKTU5hV2pxSGM3T0xEQ1I1ZUg5R2E0azdkM2wzTmEvSG9SaEtpL1lJRHQwTWRuZmpIbnVRTWxkL2tPa0JIWkRHNWw1bm1IaFB5QWVFPS0tWmVudHRhS2RqZ0Q0MmpIU1NMdTFGQT09--e3d534cf9b52e04a57a8c37a053d4a3af6d486f1"))
//    }
//    return response.status.code == 200
//}
//
//func syncProject(name:String, req:Request) async throws -> Bool {
//    let uri = URI(string: "https://gitee.com/swift-package-manager-mirror/\(name)/force_sync_project")
//    let response = try await req.client.post(uri, beforeSend: { request in
//        let cookies = HTTPCookies(dictionaryLiteral: ("gitee-session-n","TStHOTA5ekVuckdXZENMQUhZVitFM3lwRGMzUXYwMGRaNlpTY2N5OTNVZDRraVlqN3pyQllIbVFrSmdBTnExSTh6SzNLR0VaM2FXQUxvNXl1VXMrQXpCWXVwRk1xSEhyeFdwWmthblFOa2dxazJTcjI1aWY0U3FzekF6MGhaaU5mT3B3VzA0T2x0U1gwS2t5ZVhVc0VvQVhSclVNcDBNd0RwQVZHZWdqYlVmRTVXbUlYWk9qdTlhZmZsUURGSmY4WGdsWHJrRm53S3NDM1hhMmdST0QxNFF6OEhjSG0vemRqZVczdlNORHhXL016RWM0dXlCT3l5SmRGUEZ5VWRUcHlqQkJJOG9oeHJ6ajhrWHJZZ2RiR0NZWmZDYkFTYzgwWUhyRzhzN3JhdVZZV3pQWEFJSVFFUW9kTUlkSitLRFl6Q3dZVWZxblVxNm1TMm8vREZYYUpiUVdFU2VmVzVsNGJuaWR2eHhHYW5ZPS0tVVE2M25xUVBQZmRhdFRhamFDbFBSQT09--7a0a137faa5201be5a38258668363b35dc39eafb"))
//        request.headers.cookie = cookies
//    })
//    return response.status.code == 200
//}
//
//
//func getContent(file:String, req:Request) async throws {
//    let uri = URI(string: "\(giteeApi)/repos/swift-package-manager-mirror/mirror-repos/contents/\(file)?access_token=\(accessToken)")
//    let response = try await req.client.get(uri)
//}
//
//struct Repo: Content {
//    
//}
