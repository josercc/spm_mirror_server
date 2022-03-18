//
//  MirringData.swift
//  
//
//  Created by admin on 2022/3/14.
//

import Foundation

let mirror = MirringData()

actor MirringData {
    var packages:[String] = []
    var mirrors:[String:String] = [:]
    func append(_ package:String) {
        packages.append(package)
    }
    func remove(_ package:String) {
        guard let index = packages.firstIndex(where: {$0 == package}) else {
            return
        }
        packages.remove(at: index)
    }
}
