//
//  UpdateMirror003.swift
//  
//
//  Created by 张行 on 2022/4/11.
//

import Foundation
import FluentKit

struct UpdateMirror003: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Mirror.schema)
            .field("wait_progress_count", .int)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Mirror.schema)
            .delete()
    }
}
