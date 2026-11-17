//
//  AnimationSystem.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import Foundation
import MetalKit

struct AnimationSystem: System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {
        
    }
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        for (entity, animComp, skelComp) in manager.query(AnimationComponent.self, SkeletonComponent.self) {
            var animationComponent = animComp
            var skeletonComponent = skelComp
            
            // 1. Получаем ТЕКУЩИЙ клип по имени
            guard let currentClip = animationComponent.clips[animationComponent.currentClipName] else { continue }
            
            // 2. Обновляем время
            animationComponent.currentTime += deltaTime * animationComponent.speed
            let time = fmod(animationComponent.currentTime, currentClip.duration)
            
            // 3. Считаем локальные позы (используем currentClip, а не просто clip)
            var localPose = [float4x4](repeating: .identity, count: skeletonComponent.jointPaths.count)
            for index in 0..<skeletonComponent.jointPaths.count {
                let pose = currentClip.getPose(at: time * animationComponent.speed,
                                               jointPath: skeletonComponent.jointPaths[index])
                ?? skeletonComponent.restTransforms[index]
                localPose[index] = pose
            }
            
            var worldPose: [float4x4] = []
            for index in 0..<skeletonComponent.parentIndices.count {
                let parentIndex = skeletonComponent.parentIndices[index]
                let localMatrix = localPose[index]
                if let parentIndex {
                    worldPose.append(worldPose[parentIndex] * localMatrix)
                } else {
                    worldPose.append(localMatrix)
                }
            }
            
            for index in 0..<worldPose.count {
                worldPose[index] *= skeletonComponent.bindTransforms[index].inverse
            }
            skeletonComponent.currentPose = worldPose
            
            manager.addComponent(component: animationComponent, to: entity)
            manager.addComponent(component: skeletonComponent, to: entity)
            
            for child in manager.children(of: entity) {
                guard let skin = manager.getComponent(for: child) as SkinComponent? else { continue }
                
                // Получаем указатель на память видеокарты
                let palettePointer = skin.jointMatrixPaletteBuffer.contents().bindMemory(
                    to: float4x4.self,
                    capacity: skin.skinToSkeletonMap.count
                )
                
                // Копируем матрицы из скелета в буфер скина
                for i in 0..<skin.skinToSkeletonMap.count {
                    let skelIndex = skin.skinToSkeletonMap[i]
                    palettePointer[i] = skeletonComponent.currentPose[skelIndex]
                }
            }
        }
    }
}
