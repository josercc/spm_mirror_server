//
//  CreateMirrorRequest.swift
//  
//
//  Created by 张行 on 2022/4/2.
//

import Foundation
import FluentKit

struct CreateMirrorRequest: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(MirrorRequest.schema)
            .id()
            .field("url", .string)
            .field("create", .double)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(MirrorRequest.schema)
            .delete()
    }
}
