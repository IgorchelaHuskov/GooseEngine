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
            
            // 1. Получаем ввод с клавиатуры
            var moveDirection = SIMD3<Float>.zero
            if input.keysPressed.contains(.keyW) { moveDirection.z += 1 }
            if input.keysPressed.contains(.keyS) { moveDirection.z -= 1 }
            if input.keysPressed.contains(.keyA) { moveDirection.x -= 1 }
            if input.keysPressed.contains(.keyD) { moveDirection.x += 1 }
            
            // --- 2. СТЕЙТ-МАШИНА ---
            if player.state == .action && animation.isFinished {
                // Прыжок закончился: сразу решаем, бежать дальше или стоять, глядя на WASD
                player.state = (moveDirection != .zero) ? .running : .idle
            }

            // Если мы НЕ в процессе прыжка (или он только что завершился строчкой выше)
            if player.state != .action {
                if input.keysPressed.contains(.spacebar) {
                    player.state = .action
                } else if moveDirection != .zero {
                    player.state = .running
                } else {
                    player.state = .idle
                }
            }
            
        
            
            // --- 3. ВЫБОР АНИМАЦИИ ---
            switch player.state {
            case .running:
                if let newClip = findClip(containing: "run", in: animation.clips) {
                    // Бег: зациклен (loop: true), двигается кодом (rootMotion: false)
                    animation.crossfade(to: newClip, duration: 0.2, loop: true, rootMotion: false)
                }
            case .action:
                let jumpClip = findClip(containing: "jump", in: animation.clips) ?? findClip(containing: "action", in: animation.clips)
                if let newClip = jumpClip {
                    // Прыжок: НЕ зациклен (loop: false), двигается анимацией (rootMotion: true)
                    animation.crossfade(to: newClip, duration: 0.15, loop: false, rootMotion: true)
                }
            case .idle:
                if let newClip = findClip(containing: "idle", in: animation.clips) {
                    // Покой: зациклен (loop: true), без движения (rootMotion: false)
                    animation.crossfade(to: newClip, duration: 0.2, loop: true, rootMotion: false)
                }
            }
            
            // --- 4. ДВИЖЕНИЕ ПЕРСОНАЖА ---
            if animation.applyRootMotion {
                // ВАРИАНТ А: Движение из анимации (для прыжка)
                
                // 1) Масштабируем дельту (важно для моделей Mixamo, у которых scale часто 0.01)
                let scaledDelta = animation.rootMotionDelta * transform.scale
                
                // 2) Оставляем только движение по земле (X и Z), так как высота Y уже есть в самой анимации
                let localHorizontalDelta = SIMD3<Float>(scaledDelta.x, 0, scaledDelta.z)
                
                // 3) Поворачиваем локальный вектор туда, куда сейчас смотрит персонаж
                let worldDelta = transform.rotationQuat.act(localHorizontalDelta)
                
                // 4) Сдвигаем персонажа в мире
                transform.position += worldDelta
                
                // 5) Обязательно обнуляем дельту, так как мы её уже применили в этом кадре
                animation.rootMotionDelta = .zero
                
            } else if moveDirection != .zero {
                // ВАРИАНТ Б: Обычное управление с клавиатуры (для бега)
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
            
            // --- 5. СОХРАНЯЕМ КОМПОНЕНТЫ ---
            manager.addComponent(component: player, to: entity)
            manager.addComponent(component: transform, to: entity)
            manager.addComponent(component: animation, to: entity)
        }
    }
    
    private func findClip(containing keyword: String, in clips: [String: AnimationClip]) -> String? {
        return clips.keys.first { $0.localizedCaseInsensitiveContains(keyword) }
    }
}

