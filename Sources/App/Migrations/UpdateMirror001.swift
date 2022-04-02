//
//  UpdateMirror001.swift
//  
//
//  Created by king on 2022/4/3.
//

import Foundation
import FluentKit

struct UpdateMirror001: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Mirror.schema)
            .field("request_mirror_count", .int)
            .field("last_mirror_date", .double)
            .update()
        let mirrors = try await Mirror.query(on: database).all()
        for mirror in mirrors {
            mirror.lastMittorDate = Date().timeIntervalSince1970
            mirror.requestMirrorCount = 0
            try await mirror.update(on: database)
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Mirror.schema).delete()
    }
}
