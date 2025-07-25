//
//  SymbolInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI

@Observable
final class SymbolInstance: Identifiable, Codable, Transformable {

    var id: UUID

    var symbolUUID: UUID
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .west

    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(id: UUID = UUID(), symbolUUID: UUID, position: CGPoint, cardinalRotation: CardinalRotation = .west) {
        self.id = id
        self.symbolUUID = symbolUUID
        self.position = position
        self.cardinalRotation = cardinalRotation
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _symbolUUID = "symbolUUID"
        case _position = "position"
        case _cardinalRotation = "rotation"
    }
    
    /// Creates a new instance with the same property values.
    func copy() -> SymbolInstance {
        SymbolInstance(id: id,
                       symbolUUID: symbolUUID,
                       position: position,
                       cardinalRotation: cardinalRotation)
    }
}

// Add Equatable conformance to allow value-based comparisons.
extension SymbolInstance: Equatable {
    static func == (lhs: SymbolInstance, rhs: SymbolInstance) -> Bool {
        lhs.id == rhs.id &&
        lhs.symbolUUID == rhs.symbolUUID &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation
    }
}