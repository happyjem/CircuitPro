//
//  CanvasToolContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct CanvasToolContext {
    var existingPinCount: Int = 0
    var existingPadCount: Int = 0
    var selectedLayer: CanvasLayer = .layer0
    var magnification: CGFloat = 1.0
    var hitTarget: CanvasHitTarget?
    var schematicGraph: SchematicGraph?
    /// Number of consecutive clicks at the current location (for double-tap detection).
    var clickCount: Int = 1
}
