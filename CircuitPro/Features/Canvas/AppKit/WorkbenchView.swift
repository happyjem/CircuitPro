//
//  WorkbenchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit
import UniformTypeIdentifiers

final class WorkbenchView: NSView {

    // MARK: Sub-views
    weak var backgroundView: DottedBackgroundView?
    weak var sheetView:      DrawingSheetView?
    weak var elementsView:   ElementsView?
    weak var connectionsView: ConnectionsView?
    weak var previewView:    PreviewView?
    weak var handlesView:    HandlesView?
    weak var marqueeView:    MarqueeView?
    weak var crosshairsView: CrosshairsView?
    weak var guideView:      GuideView?

    // MARK: Model / view-state
    var elements: [CanvasElement] = [] {
        didSet {
            elementsView?.elements  = elements
            handlesView?.elements   = elements
    
            
            // Update the schematic graph with new pin positions
            syncPinPositionsToGraph()
        }
    }
    
    var schematicGraph: SchematicGraph = .init() {
        didSet {
            connectionsView?.schematicGraph = schematicGraph
        }
    }

    var selectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.selectedIDs = selectedIDs
            handlesView?.selectedIDs  = selectedIDs
            connectionsView?.selectedIDs  = selectedIDs
        }
    }

    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.marqueeSelectedIDs = marqueeSelectedIDs
            connectionsView?.marqueeSelectedIDs = marqueeSelectedIDs
        }
    }

    var selectedTool: AnyCanvasTool? {
        didSet {
            previewView?.selectedTool = selectedTool
            if window?.firstResponder != self {
                window?.makeFirstResponder(self)
            }
        }
    }

    var selectedLayer: CanvasLayer = .layer0

    var magnification: CGFloat = 1.0 {
        didSet {
            guard magnification != oldValue else { return }
            backgroundView?.magnification = magnification
            crosshairsView?.magnification = magnification
            marqueeView?.magnification    = magnification
            previewView?.magnification    = magnification
            handlesView?.magnification    = magnification
            connectionsView?.magnification = magnification
            guideView?.magnification      = magnification
        }
    }

    var isSnappingEnabled: Bool = true
    var snapGridSize:      CGFloat = 10.0 {
        didSet {
            backgroundView?.unitSpacing = snapGridSize
        }
    }

    var showGuides: Bool = false {
        didSet {
            guard showGuides != oldValue else { return }
            
            let origin = showGuides ? CGPoint(x: bounds.midX, y: bounds.midY) : .zero
            
            backgroundView?.gridOrigin = origin
            
            if let guideView = self.guideView {
                guideView.isHidden = !showGuides
                guideView.origin = showGuides ? origin : nil
            }
            
            backgroundView?.needsLayout = true
        }
    }

    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet { crosshairsView?.crosshairsStyle = crosshairsStyle }
    }

    var paperSize: PaperSize = .iso(.a4)

    var sheetOrientation: PaperOrientation = .landscape

    var sheetCellValues: [String:String] = [:] {
        didSet { sheetView?.cellValues = sheetCellValues }
    }

    

    // MARK: Callbacks
    var onUpdate:          (([CanvasElement]) -> Void)?
    var onSelectionChange: ((Set<UUID>)      -> Void)?
    var onPrimitiveAdded:  ((UUID, CanvasLayer) -> Void)?
    var onMouseMoved:      ((CGPoint)        -> Void)?
    var onPinHoverChange:  ((UUID?)          -> Void)?
    var onComponentDropped: ((TransferableComponent, CGPoint) -> Void)?

    // MARK: Controllers
    lazy var layout     = WorkbenchLayoutController(host: self)
    let  hitTestService    = WorkbenchHitTestService()
    lazy var input      = WorkbenchInputCoordinator(workbench: self, hitTest: hitTestService)

    var isRotating: Bool { input.isRotating }

    // MARK: NSView overrides
    override var acceptsFirstResponder: Bool { true }

    // MARK: Init
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        
        self.registerForDraggedTypes([.transferableComponent])
        
        _ = layout
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        _ = layout
    }

    // MARK: Tracking & events
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseMoved(with e: NSEvent)   { input.mouseMoved(e) }
    override func mouseEntered(with e: NSEvent) { input.mouseMoved(e) }
    override func mouseExited(with e: NSEvent)  { input.mouseExited() }
    override func mouseDown(with e: NSEvent)    { input.mouseDown(e) }
    override func mouseDragged(with e: NSEvent) { input.mouseDragged(e) }
    override func mouseUp(with e: NSEvent)      { input.mouseUp(e) }

    override func keyDown(with e: NSEvent) {
        if !input.keyDown(e) { super.keyDown(with: e) }
    }

    // MARK: Public helpers
    func reset() { input.reset() }

    var snapService: SnapService {
        let origin = showGuides ? CGPoint(x: bounds.midX, y: bounds.midY) : .zero
        return SnapService(gridSize: snapGridSize,
                           isEnabled: isSnappingEnabled,
                           origin: origin)
    }
    
    /// Ensures the schematic graph has vertices for every symbol pin, that their
    /// positions are up-to-date, and that vertices for deleted symbols are removed.
    private func syncPinPositionsToGraph() {
        // 1. Get all symbol IDs currently on the workbench
        let currentSymbolIDs = Set<UUID>(elements.compactMap {
            guard case .symbol(let symbol) = $0 else { return nil }
            return symbol.id
        })

        // 2. Find and remove vertices from the graph that belong to deleted symbols
        let verticesToRemove = schematicGraph.vertices.values.filter { vertex in
            if case .pin(let symbolID, _) = vertex.ownership {
                return !currentSymbolIDs.contains(symbolID)
            }
            return false
        }
        
        if !verticesToRemove.isEmpty {
            schematicGraph.delete(items: Set(verticesToRemove.map { $0.id }))
        }

        // 3. Update existing pins and add new ones
        for element in elements {
            guard case .symbol(let symbolElement) = element else { continue }
            
            let transform = CGAffineTransform(translationX: symbolElement.position.x, y: symbolElement.position.y)
                .rotated(by: symbolElement.rotation)

            for pin in symbolElement.symbol.pins {
                let worldPinPosition = pin.position.applying(transform)

                // First, check if the vertex already exists for this pin.
                if let vertexID = schematicGraph.findVertex(ownedBy: symbolElement.id, pinID: pin.id) {
                    // It exists, just move it to the correct position.
                    schematicGraph.moveVertex(id: vertexID, to: worldPinPosition)
                } else {
                    // It doesn't exist, so we must create it.
                    // This is the operation that should only happen once per pin.
                    schematicGraph.getOrCreatePinVertex(
                        at: worldPinPosition,
                        symbolID: symbolElement.id,
                        pinID: pin.id
                    )
                }
            }
        }
    }

    // old public helpers (still used by all gesture classes)
    func snap(_ p: CGPoint) -> CGPoint    { snapService.snap(p) }
    func snapDelta(_ v: CGFloat) -> CGFloat { snapService.snapDelta(v) }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        input.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        input.draggingUpdated(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        input.performDragOperation(sender)
    }

}
