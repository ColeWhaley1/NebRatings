//
//  Item.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
