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
            .field("need_update", .bool)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Mirror.schema).delete()
    }
}
