//
//  ThirdPersonCameraSystem.swift
//  GooseForge
//
//  Created by Igorchela on 18.11.2026.
//

import Foundation

import Foundation
import simd
internal import GameController

struct ThirdPersonCameraSystem: System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {}
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        let input = InputController.shared
        
        // Ищем TPS камеру
        for (entity, camComp, transformComp) in manager.query(ThirdPersonCameraComponent.self, TransformComponent.self) {
            var cam = camComp
            var transform = transformComp
            
            // 1. Если камера не активна, пропускаем ввод
            if scene.activeCameraID != entity { continue }
            
            // 2. Ввод мыши (вращение)
            if input.leftMouseDown && !input.gizmoCaptured {
                let sensitivity = Settings.mousePanSensitivity
                cam.pitch += input.mouseDelta.y * sensitivity
                cam.yaw   += input.mouseDelta.x * sensitivity
                cam.pitch = max(-.pi / 2 + 0.1, min(cam.pitch, .pi / 2 - 0.1))
                input.mouseDelta = .zero
            }
            
            // 3. Зум колесиком
            let scroll = (input.mouseScroll.x + input.mouseScroll.y) * Settings.mouseScrollSensitivity * 10
            cam.distance -= scroll
            cam.distance = max(cam.minDistance, min(cam.distance, cam.maxDistance))
            input.mouseScroll = .zero
            
            // 4. Находим игрока
            if let targetTransform = manager.getComponent(for: cam.targetEntity) as TransformComponent? {
                // Точка, вокруг которой вращаемся (чуть выше ног персонажа)
                let targetPos = targetTransform.position + float3(0, 1.5, 0)
                
                // 5. Считаем позицию камеры сзади
                let rotationMatrix = float4x4(rotationYXZ: [-cam.pitch, cam.yaw, 0])
                let distanceVector = float4(0, 0, -cam.distance, 0)
                let rotatedVector = rotationMatrix * distanceVector
                
                let camPos = targetPos + rotatedVector.xyz
                
                // 6. Обновляем Transform камеры
                transform.position = camPos
                transform.rotationQuat = quatFromEulerYXZ([-cam.pitch, cam.yaw, 0])
                
                // Сохраняем
                manager.addComponent(component: transform, to: entity)
                manager.addComponent(component: cam, to: entity)
            }
        }
    }
}
