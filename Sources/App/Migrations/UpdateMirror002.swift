//
//  UpdateMirror002.swift
//  
//
//  Created by king on 2022/4/3.
//

import Foundation
import FluentKit

struct UpdateMirror002: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Mirror.schema)
            .field("wait_count", .int)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await Mirror.query(on: database).delete()
    }
}
