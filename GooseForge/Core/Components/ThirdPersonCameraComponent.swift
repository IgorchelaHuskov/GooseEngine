//
//  ThirdPersonCameraComponent.swift
//  GooseForge
//
//  Created by Igorchela on 18.11.2026.
//

import Foundation

struct ThirdPersonCameraComponent: Component {
    var aspect: Float = 1.0
    var fov: Float = Float(70).degreesToRadians
    var near: Float = 0.1
    var far: Float = 1000
    
    // Состояние орбиты
    var distance: Float = 5.0
    var minDistance: Float = 1.0
    var maxDistance: Float = 15.0
    var pitch: Float = -0.2 // Наклон вверх/вниз
    var yaw: Float = 0.0    // Вращение вокруг персонажа
    
    // Кого мы преследуем
    var targetEntity: Entity
    
    var projectionMatrix: float4x4 {
        float4x4(projectionFov: fov, near: near, far: far, aspect: aspect)
    }
}
