//
//  MirrorRepo.swift
//  
//
//  Created by king on 2022/3/27.
//

import Foundation
import Vapor

struct MirrorRepo: Codable {
    let origin:String
    var mirror:String
}
