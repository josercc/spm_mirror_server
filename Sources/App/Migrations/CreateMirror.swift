//
//  CreateMirror.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation
import Vapor
import FluentKit
struct CreateMirror: AsyncMigration {
    func prepare(on database: Database) async throws {
        return try await database.schema(Mirror.schema)
            .id()
            .field("origin", .string)
            .field("mirror",.string)
            .field("create", .double)
            .field("is_exit", .bool)
            .create()
    }
    
    func revert(on database: Database) async throws {
        return try await database.schema(Mirror.schema).delete()
    }
}
