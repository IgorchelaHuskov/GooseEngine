//
//  AnimationComponent.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import Foundation

struct AnimationComponent: Component {
    var currentTime: Float = 0
    var speed: Float = 1
    var clips: [String: AnimationClip] = [:]
    var currentClipName: String = ""
    
    // Поля для Crossfade
    var previousClipName: String? = nil
    var previousTime: Float = 0
    var blendTime: Float = 0
    var blendDuration: Float = 0.2
    
    // --- Поля для Root Motion ---
    var applyRootMotion: Bool = false       // Включаем только для нужных анимаций (например, прыжок, атака)
    var rootJointIndex: Int = 0             // Индекс кости таза (Hips) в массиве jointPaths
    var previousRootPosition: SIMD3<Float> = .zero
    var rootMotionDelta: SIMD3<Float> = .zero // Сюда AnimationSystem запишет сдвиг за кадр
    
    // Флаг зацикливания, чтобы прыжок не повторялся бесконечно
    var isLooping: Bool = true
    var isFinished: Bool = false
    
    mutating func crossfade(to newClipName: String, duration: Float = 0.2, loop: Bool = true, rootMotion: Bool = false) {
        guard newClipName != currentClipName else { return }
        
        previousClipName = currentClipName
        previousTime = currentTime
        
        currentClipName = newClipName
        currentTime = 0
        blendTime = 0
        blendDuration = duration
        
        isLooping = loop
        isFinished = false
        applyRootMotion = rootMotion
        
        // Сбрасываем позицию корня для новой анимации (инициализируем её на первом кадре в AnimationSystem)
        previousRootPosition = .zero
        rootMotionDelta = .zero
    }
}

