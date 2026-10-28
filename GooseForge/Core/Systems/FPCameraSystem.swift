//
//  FPCameraSystem.swift
//  ECSRenderer
//
//  Created by Igorchela on 11.08.2026.
//

import Foundation

struct FPCameraSystem: System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {
        guard var cameraComponent = manager.getComponent(for: scene.activeCameraID) as FPCameraComponent? else { return }
        cameraComponent.aspect = Float(size.width / size.height)
        manager.addComponent(component: cameraComponent, to: scene.activeCameraID)
    }
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {}
    
}
