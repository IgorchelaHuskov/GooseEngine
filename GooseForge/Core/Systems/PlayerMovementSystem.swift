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
            
            // 1. Ввод с клавиатуры
            var moveDirection = SIMD3<Float>.zero
            if input.keysPressed.contains(.keyW) { moveDirection.z += 1 }
            if input.keysPressed.contains(.keyS) { moveDirection.z -= 1 }
            if input.keysPressed.contains(.keyA) { moveDirection.x -= 1 }
            if input.keysPressed.contains(.keyD) { moveDirection.x += 1 }
            
            if !input.keysPressed.contains(.spacebar) {
                player.canJump = true
            }
            
            // 2. Стейт-машина
            if player.state == .action && animation.isFinished {
                player.state = (moveDirection != .zero) ? .running : .idle
                player.currentAction = ""
            }
            
            if player.state != .action {
                if input.keysPressed.contains(.spacebar) && player.canJump {
                    player.state = .action
                    player.currentAction = "jump"
                    player.canJump = false
                } else if input.keysPressed.contains(.keyF) {
                    // Пример добавления новой анимации атаки на клавишу F:
                    player.state = .action
                    player.currentAction = "attack"
                } else if moveDirection != .zero {
                    player.state = .running
                } else {
                    player.state = .idle
                }
            }
            
            // 3. Запуск анимации через таблицу действий
            switch player.state {
            case .idle:
                animation.play(action: "idle")
            case .running:
                animation.play(action: "run")
            case .action:
                // Пытаемся запустить действие (например, "jump" или "attack").
                // Если в эдиторе эту анимацию удалили или еще не добавили — play вернет false, и мы сразу сбросим состояние!
                if !animation.play(action: player.currentAction) {
                    player.state = (moveDirection != .zero) ? .running : .idle
                    player.currentAction = ""
                }
            }
            
            // 4. Движение персонажа (ваш рабочий код без изменений)
            if animation.applyRootMotion {
                let scaledDelta = animation.rootMotionDelta * transform.scale
                let localHorizontalDelta = SIMD3<Float>(scaledDelta.x, 0, scaledDelta.z)
                let worldDelta = transform.rotationQuat.act(localHorizontalDelta)
                
                transform.position += worldDelta
                animation.rootMotionDelta = .zero
                
            } else if moveDirection != .zero {
                if let camTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent? {
                    let camForward = camTransform.rotationQuat.act([0, 0, 1])
                    let flatForward = simd_normalize(SIMD3<Float>(camForward.x, 0, camForward.z))
                    let camRight = simd_normalize(simd_cross([0, 1, 0], flatForward))
                    
                    let worldDirection = (flatForward * moveDirection.z) + (camRight * moveDirection.x)
                    let finalDir = simd_normalize(worldDirection)
                    
                    transform.position += finalDir * player.speed * deltaTime
                    
                    let targetQuat = simd_quatf(from: [0, 0, 1], to: finalDir)
                    transform.rotationQuat = simd_slerp(transform.rotationQuat, targetQuat, deltaTime * 10.0)
                }
            }
            
            // 5. Сохраняем компоненты
            manager.addComponent(component: player, to: entity)
            manager.addComponent(component: transform, to: entity)
            manager.addComponent(component: animation, to: entity)
        }
    }
}
