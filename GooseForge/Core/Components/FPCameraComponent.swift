//
//  FPCameraComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 10.08.2026.
//

import Foundation

import Foundation
import simd

struct FPCameraComponent: Component {
    var aspect: Float = 1.0
    var fov: Float = Float(70).degreesToRadians
    var near: Float = 0.1
    var far: Float = 20

    /// Состояние управления — источник правды для ориентации.
    /// pitch клампится ±π/2 (в InputSystem), yaw свободный.
    var yaw: Float = 0
    var pitch: Float = 0

    var projectionMatrix: float4x4 {
        float4x4(projectionFov: fov, near: near, far: far, aspect: aspect)
    }

    /// Кватернион, восстановленный из yaw/pitch.
    /// Знак −pitch сохранён из старого Renderer'а (инверсия для view-матрицы).
    var orientationQuat: simd_quatf {
        quatFromEulerYXZ([-pitch, yaw, 0])
    }
}

