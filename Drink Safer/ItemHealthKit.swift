//
//  ItemHealthKit.swift
//  Drink Safer
//
//  Created by Bryce Ellis on 9/21/24.
//

import Foundation
import SwiftData

@Model
final class ItemHealthKit {
    var abvPercentage: Double
    
    init(abvPercentage: Double) {
        self.abvPercentage = abvPercentage
    }
}
