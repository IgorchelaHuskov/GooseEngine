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
            
            guard let currentClip = animationComponent.clips[animationComponent.currentClipName] else { continue }
            
            // 1. Обновляем время текущей анимации
            animationComponent.currentTime += deltaTime * animationComponent.speed
            let currentLocalTime: Float
            if animationComponent.isLooping {
                currentLocalTime = fmod(animationComponent.currentTime, currentClip.duration)
            } else {
                if animationComponent.currentTime >= currentClip.duration {
                    currentLocalTime = currentClip.duration
                    animationComponent.isFinished = true
                } else {
                    currentLocalTime = animationComponent.currentTime
                }
            }
            
            // 2. Проверяем, активен ли сейчас переход (Crossfade)
            var isBlending = false
            var blendWeight: Float = 1.0
            var prevClip: AnimationClip? = nil
            var prevLocalTime: Float = 0
            
            if let prevName = animationComponent.previousClipName,
               let clip = animationComponent.clips[prevName] {
                
                animationComponent.blendTime += deltaTime
                if animationComponent.blendTime < animationComponent.blendDuration {
                    isBlending = true
                    prevClip = clip
                    // Вычисляем прогресс от 0.0 (старая поза) до 1.0 (новая поза)
                    blendWeight = animationComponent.blendTime / animationComponent.blendDuration
                    
                    // Продолжаем проигрывать старую анимацию, чтобы переход был живым
                    animationComponent.previousTime += deltaTime * animationComponent.speed
                    prevLocalTime = fmod(animationComponent.previousTime, clip.duration)
                } else {
                    // Переход завершен, очищаем предыдущий клип
                    animationComponent.previousClipName = nil
                }
            }
            
            // 3. Считаем локальные позы с учетом смешивания
            var localPose = [float4x4](repeating: .identity, count: skeletonComponent.jointPaths.count)
            
            for index in 0..<skeletonComponent.jointPaths.count {
                let jointPath = skeletonComponent.jointPaths[index]
                let restTransform = skeletonComponent.restTransforms[index]
                
                // Поза новой анимации
                let targetMatrix = currentClip.getPose(at: currentLocalTime, jointPath: jointPath) ?? restTransform
                
                if isBlending, let previousClip = prevClip {
                    // Поза старой анимации
                    let prevMatrix = previousClip.getPose(at: prevLocalTime, jointPath: jointPath) ?? restTransform
                    // Смешиваем две матрицы
                    localPose[index] = blendMatrices(from: prevMatrix, to: targetMatrix, weight: blendWeight)
                } else {
                    localPose[index] = targetMatrix
                }
                
                if index != animationComponent.rootJointIndex {
                    // Оставляем вращение и масштаб из анимации, но позицию берем строго из базовой позы (restTransform)!
                    localPose[index].columns.3 = restTransform.columns.3
                }
            }
            
            let rootIdx = animationComponent.rootJointIndex
            if rootIdx < localPose.count {
                // Извлекаем текущую локальную позицию кости Hips из матрицы
                let currentRootPos = SIMD3<Float>(
                    localPose[rootIdx].columns.3.x,
                    localPose[rootIdx].columns.3.y,
                    localPose[rootIdx].columns.3.z
                )
                
                if animationComponent.applyRootMotion {
                    // Если это самый первый кадр после запуска клипа, просто запоминаем базу
                    if animationComponent.previousRootPosition == .zero {
                        animationComponent.previousRootPosition = currentRootPos
                        animationComponent.rootMotionDelta = .zero
                    } else {
                        // Считаем, насколько сдвинулся таз с прошлого кадра
                        let delta = currentRootPos - animationComponent.previousRootPosition
                        animationComponent.rootMotionDelta = delta
                        animationComponent.previousRootPosition = currentRootPos
                    }
                    
                    // ОБНУЛЯЕМ горизонтальный сдвиг (X и Z) в самой кости!
                    // Высоту (Y) оставляем, чтобы персонаж красиво поджимал ноги в прыжке.
                    // (Если хотите, чтобы физика сама поднимала игрока по Y, обнулите и Y, а delta.y применяйте к transform.position.y)
                    localPose[rootIdx].columns.3.x = 0
                    localPose[rootIdx].columns.3.z = 0
                    
                } else {
                    // Если Root Motion выключен (например, в Idle или Run с галочкой In-Place)
                    animationComponent.rootMotionDelta = .zero
                    animationComponent.previousRootPosition = currentRootPos
                }
            }
            
            // 4. Cтандартный расчет worldPose и обновление буфера видеокарты...
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

extension AnimationSystem {
    private func blendMatrices(from m1: float4x4, to m2: float4x4, weight: Float) -> float4x4 {
        // 1. Позиция
        let pos1 = SIMD3<Float>(m1.columns.3.x, m1.columns.3.y, m1.columns.3.z)
        let pos2 = SIMD3<Float>(m2.columns.3.x, m2.columns.3.y, m2.columns.3.z)
        let blendedPos = simd_mix(pos1, pos2, SIMD3<Float>(repeating: weight))
        
        // 2. Масштаб (защита от деления на ноль через max(..., 0.0001))
        let s1x = max(simd_length(SIMD3<Float>(m1.columns.0.x, m1.columns.0.y, m1.columns.0.z)), 0.0001)
        let s1y = max(simd_length(SIMD3<Float>(m1.columns.1.x, m1.columns.1.y, m1.columns.1.z)), 0.0001)
        let s1z = max(simd_length(SIMD3<Float>(m1.columns.2.x, m1.columns.2.y, m1.columns.2.z)), 0.0001)
        let scale1 = SIMD3<Float>(s1x, s1y, s1z)
        
        let s2x = max(simd_length(SIMD3<Float>(m2.columns.0.x, m2.columns.0.y, m2.columns.0.z)), 0.0001)
        let s2y = max(simd_length(SIMD3<Float>(m2.columns.1.x, m2.columns.1.y, m2.columns.1.z)), 0.0001)
        let s2z = max(simd_length(SIMD3<Float>(m2.columns.2.x, m2.columns.2.y, m2.columns.2.z)), 0.0001)
        let scale2 = SIMD3<Float>(s2x, s2y, s2z)
        
        let blendedScale = simd_mix(scale1, scale2, SIMD3<Float>(repeating: weight))
        
        // 3. Вращение (берем только 3x3 часть и обязательно нормализуем кватернионы!)
        let rotMat1 = float3x3(
            SIMD3<Float>(m1.columns.0.x, m1.columns.0.y, m1.columns.0.z) / scale1.x,
            SIMD3<Float>(m1.columns.1.x, m1.columns.1.y, m1.columns.1.z) / scale1.y,
            SIMD3<Float>(m1.columns.2.x, m1.columns.2.y, m1.columns.2.z) / scale1.z
        )
        let rotMat2 = float3x3(
            SIMD3<Float>(m2.columns.0.x, m2.columns.0.y, m2.columns.0.z) / scale2.x,
            SIMD3<Float>(m2.columns.1.x, m2.columns.1.y, m2.columns.1.z) / scale2.y,
            SIMD3<Float>(m2.columns.2.x, m2.columns.2.y, m2.columns.2.z) / scale2.z
        )
        
        let quat1 = simd_normalize(simd_quatf(rotMat1))
        let quat2 = simd_normalize(simd_quatf(rotMat2))
        let blendedRot = simd_slerp(quat1, quat2, weight)
        
        // 4. Сборка матрицы
        var result = float4x4(blendedRot)
        result.columns.0 *= blendedScale.x
        result.columns.1 *= blendedScale.y
        result.columns.2 *= blendedScale.z
        result.columns.3 = SIMD4<Float>(blendedPos.x, blendedPos.y, blendedPos.z, 1.0)
        
        return result
    }


}
