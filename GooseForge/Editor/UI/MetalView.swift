import SwiftUI
import MetalKit

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#elseif os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#endif

struct MetalView: View {
    let options: Options
    let editor: EditorState
    @State private var mtkView = MTKView()
    @State private var previousTranslation: CGSize = .zero
    @State private var dragStart: CGPoint?
    
    var body: some View {
        MetalViewRepresentable(view: mtkView, options: options, editor: editor)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Запомнили стартовую точку — но только один раз за жест
                        if dragStart == nil {
                            dragStart = value.startLocation
                            previousTranslation = .zero
                            InputController.shared.isMouseButtonDown = true
                        }
                        
                        // Считаем суммарное смещение от старта
                        let totalMoved = hypot(
                            value.location.x - value.startLocation.x,
                            value.location.y - value.startLocation.y)
                        
                        // Пока не сдвинулись на порог — не считаем это драгом
                        if totalMoved < 3 { return }
                        
                        let delta = CGSize(
                            width:  value.translation.width  - previousTranslation.width,
                            height: value.translation.height - previousTranslation.height
                        )
                        previousTranslation = value.translation
                        
                        InputController.shared.touchLocation = value.location
                        InputController.shared.touchDelta = delta
                    }
                    .onEnded { value in
                        let totalMoved = hypot(
                            value.location.x - value.startLocation.x,
                            value.location.y - value.startLocation.y)
                        
                        previousTranslation = .zero
                        InputController.shared.touchLocation = nil
                        InputController.shared.touchDelta = nil
                        InputController.shared.isMouseButtonDown = false  
                        
                        // Мало двигались = это был клик, а не драг
                        if totalMoved < 3 {
                            InputController.shared.requestPick(at: value.location)
                        }
                        dragStart = nil
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    InputController.shared.hoverLocation = location
                case .ended:
                    InputController.shared.hoverLocation = nil
                }
            }
        
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        InputController.shared.mouseScroll.x = Float(value - 1.0)
                    }
                    .onEnded { _ in
                        InputController.shared.mouseScroll.x = 0
                    }
            )
    }
}

struct MetalViewRepresentable: ViewRepresentable {
    let view: MTKView
    let options: Options
    let editor: EditorState

    func makeCoordinator() -> EditorController {
        EditorController(metalView: view, options: options, state: editor)
    }

#if os(macOS)
    func makeNSView(context: Context) -> MTKView { view }
    func updateNSView(_ nsView: MTKView, context: Context) { }
#elseif os(iOS)
    func makeUIView(context: Context) -> MTKView { view }
    func updateUIView(_ uiView: MTKView, context: Context) { }
#endif
}
