//
//  PathContentResponse.swift
//  
//
//  Created by admin on 2022/3/19.
//

import Foundation
import Vapor

struct PathContentResponse: Content {
    let content:String
    let sha:String
}
