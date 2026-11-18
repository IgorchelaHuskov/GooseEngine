//
//  AnimationComponent.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import Foundation

// Настройки для одного действия (именно этот список вы будете редактировать в UI Эдитора)
struct AnimationAction: Codable {
    var clipName: String          // Имя клипа из словаря clips
    var isLooping: Bool = true    // Зациклена ли анимация
    var useRootMotion: Bool = false // Двигает ли анимация персонажа
    var blendDuration: Float = 0.2 // Время плавного перехода
}

struct AnimationComponent: Component {
    var currentTime: Float = 0
    var speed: Float = 1
    var clips: [String: AnimationClip] = [:]
    var currentClipName: String = ""
    
    // --- НОВОЕ: Таблица действий (например, "jump" -> настройки клипа) ---
    var actions: [String: AnimationAction] = [:]
    
    // Поля для Crossfade (оставляем как есть)
    var previousClipName: String? = nil
    var previousTime: Float = 0
    var blendTime: Float = 0
    var blendDuration: Float = 0.2
    
    // Поля для Root Motion (оставляем как есть)
    var applyRootMotion: Bool = false
    var rootJointIndex: Int = 0
    var previousRootPosition: SIMD3<Float> = .zero
    var rootMotionDelta: SIMD3<Float> = .zero
    var isLooping: Bool = true
    var isFinished: Bool = false
    
    // --- УДОБНЫЕ МЕТОДЫ ДЛЯ ДОБАВЛЕНИЯ / УДАЛЕНИЯ В КОДЕ И ЭДИТОРЕ ---
    
    /// Назначить клип на действие (например, bind(action: "attack", clipName: "Slash", loop: false, rootMotion: true))
    mutating func bind(action: String, clipName: String, loop: Bool = true, rootMotion: Bool = false, blend: Float = 0.2) {
        actions[action] = AnimationAction(
            clipName: clipName,
            isLooping: loop,
            useRootMotion: rootMotion,
            blendDuration: blend
        )
    }
    
    /// Удалить действие и/или сам клип
    mutating func removeAction(_ action: String, deleteClip: Bool = false) {
        if let removed = actions.removeValue(forKey: action), deleteClip {
            clips.removeValue(forKey: removed.clipName)
        }
    }
    
    /// Запустить действие по его имени (возвращает false, если такого действия нет)
    @discardableResult
    mutating func play(action: String) -> Bool {
        guard let config = actions[action], clips[config.clipName] != nil else {
            return false
        }
        crossfade(
            to: config.clipName,
            duration: config.blendDuration,
            loop: config.isLooping,
            rootMotion: config.useRootMotion
        )
        return true
    }
    
    // Ваш рабочий метод crossfade (без изменений)
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
        
        previousRootPosition = .zero
        rootMotionDelta = .zero
    }
}


