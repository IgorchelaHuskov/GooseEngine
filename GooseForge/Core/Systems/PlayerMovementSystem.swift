//
//  PlayerMovementSystem.swift
//  GooseForge
//
//  Created by Igorchela on 17.11.2026.
//

import Foundation
import simd
internal import GameController

struct PlayerMovementSystem: System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {
        guard var cameraComponent = manager.getComponent(for: scene.activeCameraID) as ThirdPersonCameraComponent? else { return }
        cameraComponent.aspect = Float(size.width / size.height)
        manager.addComponent(component: cameraComponent, to: scene.activeCameraID)
    }
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        let input = InputController.shared
        
        for (entity, playerComp, transformComp, animComp) in manager.query(PlayerComponent.self, TransformComponent.self, AnimationComponent.self) {
            var player = playerComp
            var transform = transformComp
            var animation = animComp
            
            // 1. Получаем ввод
            var moveDirection = SIMD3<Float>.zero
            if input.keysPressed.contains(.keyW) { moveDirection.z += 1 }
            if input.keysPressed.contains(.keyS) { moveDirection.z -= 1 }
            if input.keysPressed.contains(.keyA) { moveDirection.x -= 1 }
            if input.keysPressed.contains(.keyD) { moveDirection.x += 1 }
            
            // --- СТЕЙТ-МАШИНА ---
            if input.keysPressed.contains(.spacebar) {
                player.state = .action
            } else if moveDirection != .zero {
                player.state = .running
            } else {
                player.state = .idle
            }
            
            // Ищем нужный клип по ключевому слову (регистронезависимо)
            var targetClipName: String? = nil
            
            switch player.state {
            case .running:
                targetClipName = findClip(containing: "run", in: animation.clips)
            case .action:
                // Ищем "jump", "action" или "attack"
                targetClipName = findClip(containing: "jump", in: animation.clips) ?? findClip(containing: "action", in: animation.clips)
            case .idle:
                targetClipName = findClip(containing: "idle", in: animation.clips)
            }
            
            // Если нашли клип и он отличается от текущего — переключаем!
            if let newClip = targetClipName, animation.currentClipName != newClip {
                animation.currentClipName = newClip
                animation.currentTime = 0 // <--- ВАЖНО: Сбрасываем время, чтобы анимация начиналась с 1-го кадра
            }
            
            // --- ДВИЖЕНИЕ ---
            if moveDirection != .zero && player.state != .action {
                if let camTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent? {
                    let camForward = camTransform.rotationQuat.act([0, 0, 1])
                    let flatForward = simd_normalize(SIMD3<Float>(camForward.x, 0, camForward.z))
                    let camRight = simd_normalize(simd_cross([0, 1, 0], flatForward))
                    
                    let worldDirection = (flatForward * moveDirection.z) + (camRight * moveDirection.x)
                    let finalDir = simd_normalize(worldDirection)
                    
                    // Двигаем
                    transform.position += finalDir * player.speed * deltaTime
                    
                    // Поворачиваем
                    let targetQuat = simd_quatf(from: [0, 0, 1], to: finalDir)
                    transform.rotationQuat = simd_slerp(transform.rotationQuat, targetQuat, deltaTime * 10.0)
                }
            }
            
            // Сохраняем
            manager.addComponent(component: player, to: entity)
            manager.addComponent(component: transform, to: entity)
            manager.addComponent(component: animation, to: entity)
        }
    }
    
    // Вспомогательная функция для поиска клипа по подстроке
    private func findClip(containing keyword: String, in clips: [String: AnimationClip]) -> String? {
        return clips.keys.first { $0.localizedCaseInsensitiveContains(keyword) }
    }
}
