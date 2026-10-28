//
//  InputSystem.swift
//  ECSRenderer
//
//  Created by Igorchela on 11.08.2026.
//

import Foundation
internal import GameController
import simd

enum Settings {
    static var rotationSpeed: Float { 4.0 }
    static var translationSpeed: Float { 25.0 }
    static var mouseScrollSensitivity: Float { 0.07 }
    static var mousePanSensitivity: Float { 0.003 }
    static var touchZoomSensitivity: Float { 10 }
}

struct InputSystem: System {
    
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {}
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        guard var fpCamera = manager.getComponent(for: scene.activeCameraID) as FPCameraComponent?,
              var transform = manager.getComponent(for: scene.activeCameraID) as TransformComponent?
        else { return }
        
        var forwardVector: float3 {
            normalize([sin(fpCamera.yaw), 0, cos(fpCamera.yaw)])
        }
        var rightVector: float3 {
            [forwardVector.z, forwardVector.y, -forwardVector.x]
        }
        
        let rotationAmount = deltaTime * Settings.rotationSpeed
        let input = InputController.shared
        
        // Стрелки — поворот yaw
        if input.keysPressed.contains(.leftArrow)  { fpCamera.yaw -= rotationAmount }
        if input.keysPressed.contains(.rightArrow) { fpCamera.yaw += rotationAmount }
        
        // WASD — направление
        var direction: float3 = .zero
        if input.keysPressed.contains(.keyW) { direction.z += 1 }
        if input.keysPressed.contains(.keyS) { direction.z -= 1 }
        if input.keysPressed.contains(.keyA) { direction.x -= 1 }
        if input.keysPressed.contains(.keyD) { direction.x += 1 }
        
        // Мышь — pan камеры (yaw/pitch)
        if input.leftMouseDown && !input.gizmoCaptured {
            let sensitivity = Settings.mousePanSensitivity
            fpCamera.pitch += input.mouseDelta.y * sensitivity
            fpCamera.yaw   += input.mouseDelta.x * sensitivity
            fpCamera.pitch = max(-.pi / 2, min(fpCamera.pitch, .pi / 2))
            input.mouseDelta = .zero
        }
        
        // Scroll — вертикальное движение
        let positionYDelta = (input.mouseScroll.x + input.mouseScroll.y) * Settings.mouseScrollSensitivity
        let minY: Float = -1
        if transform.position.y + positionYDelta > minY {
            transform.position.y += positionYDelta
        }
        input.mouseScroll = .zero
        
        // WASD — перемещение в плоскости XZ
        let translationAmount = deltaTime * Settings.translationSpeed
        if direction != .zero {
            direction = normalize(direction)
            transform.position += (direction.z * forwardVector + direction.x * rightVector) * translationAmount
        }
        
        // Синхронизация: yaw/pitch → rotationQuat
        transform.rotationQuat = fpCamera.orientationQuat
        
        manager.addComponent(component: fpCamera, to: scene.activeCameraID)
        manager.addComponent(component: transform, to: scene.activeCameraID)
    }
}
