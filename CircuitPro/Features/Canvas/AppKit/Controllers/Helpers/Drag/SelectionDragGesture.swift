//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//  Refactored 17/07/25 – stripped connection-specific logic.
//

import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var originalPositions: [UUID: CGPoint] = [:] // For non-schematic elements
    private var didMove = false
    private let threshold: CGFloat = 4.0

    init(workbench: WorkbenchView) { self.workbench = workbench }

    // MARK: – Begin
    func begin(at p: CGPoint, event: NSEvent) -> Bool {
        let hitTarget = workbench.hitTestService.hitTest(
            at: p,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        guard let hitTarget = hitTarget,
              let selectableID = hitTarget.selectableID,
              workbench.selectedIDs.contains(selectableID) else {
            return false
        }

        origin = p
        originalPositions.removeAll()
        didMove = false

        // 1. Cache for standard elements
        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            originalPositions[elt.id] = elt.transformable.position
        }

        // 2. Tell the schematic graph to prepare for a drag
        workbench.schematicGraph.beginDrag(selectedIDs: workbench.selectedIDs)
        
        return true
    }

    // MARK: – Drag
    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        let rawDelta = CGPoint(x: p.x - o.x, y: p.y - o.y)

        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true
        
        let moveDelta = CGPoint(x: workbench.snapDelta(rawDelta.x),
                                y: workbench.snapDelta(rawDelta.y))

        // --- Part 1: Move standard canvas elements ---
        if !originalPositions.isEmpty {
            var updatedElements = workbench.elements
            for i in updatedElements.indices {
                guard let base = originalPositions[updatedElements[i].id] else { continue }
                updatedElements[i].moveTo(originalPosition: base, offset: moveDelta)
            }
            workbench.elements = updatedElements
            workbench.onUpdate?(updatedElements)
        }

        // --- Part 2: Update the schematic drag ---
        workbench.schematicGraph.updateDrag(by: moveDelta)
        
        
    }

    // MARK: – End
    func end() {
        if didMove {
            workbench.schematicGraph.endDrag()
        }
        
        origin = nil
        originalPositions.removeAll()
        didMove = false
        
        
    }
}
