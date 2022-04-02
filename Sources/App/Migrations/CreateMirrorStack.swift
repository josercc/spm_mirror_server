//
//  CreateMirrorStack.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import FluentKit

struct CreateMirrorStack: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(MirrorStack.schema)
            .id()
            .field("url", .string)
            .field("create", .double)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(MirrorStack.schema)
            .delete()
    }
}
