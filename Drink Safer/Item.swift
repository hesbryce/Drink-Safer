//
//  Item.swift
//  Drink Safer
//
//  Created by Bryce Ellis on 9/21/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var drinkType: String
    var volume: Double // in oz
    var alcoholContent: Double // ABV percentage

    init(timestamp: Date, drinkType: String, volume: Double, alcoholContent: Double) {
        self.timestamp = timestamp
        self.drinkType = drinkType
        self.volume = volume
        self.alcoholContent = alcoholContent
    }
}
