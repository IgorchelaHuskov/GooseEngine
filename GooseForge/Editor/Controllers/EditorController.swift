//
//  GameController.swift
//  ECSRenderer
//
//  Created by Igorchela on 07.08.2026.
//

import MetalKit

class EditorController: NSObject {
    let renderer: Renderer
    let state:    EditorState

    var entityManager: EntityManager { state.entityManager }
    var scene:         SceneManager! { state.scene }
    
    var lastTime: Double = CFAbsoluteTimeGetCurrent()
    
    init(metalView: MTKView, options: Options, state: EditorState) {
        self.state = state
        self.renderer = Renderer(metalView: metalView)
        
        let url = Bundle.main.url(forResource: "scene", withExtension: "json")
        let scene = SceneManager(manager: state.entityManager,
                                 device: Renderer.device,
                                 options: options,
                                 sceneURL: url)
        state.scene = scene  
        
        super.init()
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        renderer.tiledRenderPass.overlays.append(GizmoOverlay())
    }
}

extension EditorController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.mtkView(view, drawableSizeWillChange: size)
        scene.update(manager: entityManager, size: size)
    }
    
    func draw(in view: MTKView) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = currentTime - lastTime
        lastTime = currentTime
        scene.update(manager: entityManager, deltaTime: Float(deltaTime))
        
        if let pickPoint = InputController.shared.consumePickRequest() {
            scene.selectedEntity = renderer.tiledRenderPass.readEntityID(at: pickPoint)
        }
        
        if InputController.shared.consumeDuplicateRequest() {
            scene.duplicateSelectedEntity()
        }
        
        if InputController.shared.consumeDeleteRequest() {
            scene.deleteSelectedEntity()
        }

        
        renderer.draw(in: view, manager: entityManager, scene: scene)
    }
}

