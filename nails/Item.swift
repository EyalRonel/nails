//
//  Item.swift
//  nails
//
//  Created by Eyal Ronel on 16/06/2026.
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
