//
//  EulerQuat.swift
//  GooseForge
//
//  Created by Igorchela on 23.10.2026.
//

import simd

// Единственное место, где Euler встречается с кватернионом.
// Везде в рантайме — только simd_quatf.

func quatFromEulerYXZ(_ e: float3) -> simd_quatf {
    let qx = simd_quatf(angle: e.x, axis: [1, 0, 0])
    let qy = simd_quatf(angle: e.y, axis: [0, 1, 0])
    let qz = simd_quatf(angle: e.z, axis: [0, 0, 1])
    // YXZ: сначала Z, потом X, потом Y — соответствует float4x4(rotationYXZ:)
    return qy * qx * qz
}

func eulerYXZ(from q: simd_quatf) -> float3 {
    let m = float4x4(q)
    let m00 = m.columns.0.x, m02 = m.columns.2.x
    let m10 = m.columns.0.y, m11 = m.columns.1.y, m12 = m.columns.2.y
    let m22 = m.columns.2.z

    // Извлекаем X (наклон)
    let sx = max(-1.0, min(1.0, -m12))
    let x = asin(sx)
    let cx = (1.0 - sx * sx).squareRoot()

    // Если смотрим строго вверх/вниз (Gimbal lock)
    if cx < 1e-6 {
        let y = atan2(-m.columns.0.z, m00)
        return [x, y, 0]
    }

    // Извлекаем Y (поворот) и Z (крен)
    let y = atan2(m02, m22)
    let z = atan2(m10, m11)
    return [x, y, z]
}
