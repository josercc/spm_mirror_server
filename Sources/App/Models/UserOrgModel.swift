//
//  UserOrgModel.swift
//  
//
//  Created by 张行 on 2022/3/31.
//

import Foundation

struct UserOrgModel: Codable {
    let id: Int
    let login: String
    let name: String
    let url: String
    let avatar_url: String
    let repos_url: String
    let events_url: String
    let members_url: String
    let description: String
    let follow_count: Int
}
