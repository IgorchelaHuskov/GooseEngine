//
//  GizmoAxis.swift
//  GooseForge
//
//  Created by Igorchela on 22.10.2026.
//

import Foundation

struct Ray {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>   // нормализованное
}

enum GizmoAxis: Int, CaseIterable {
    case x, y, z
    
    var direction: SIMD3<Float> {
        switch self {
        case .x: return [1, 0, 0]
        case .y: return [0, 1, 0]
        case .z: return [0, 0, 1]
        }
    }
    var rotation: float4x4 {
        switch self {
        case .x: return float4x4(rotationZ: -Float.pi / 2)
        case .y: return .identity
        case .z: return float4x4(rotationX:  Float.pi / 2)
        }
    }
    var baseColor: SIMD4<Float> {
        switch self {
        case .x: return [1, 0, 0, 1]
        case .y: return [0, 1, 0, 1]
        case .z: return [0, 0, 1, 1]
        }
    }
    var hoverColor: SIMD4<Float> {
        switch self {
        case .x: return [1, 0.7, 0.3, 1]
        case .y: return [0.6, 1, 0.3, 1]
        case .z: return [0.3, 0.7, 1, 1]
        }
    }
    
    var ringBasis: (u: SIMD3<Float>, v: SIMD3<Float>) {
        switch self {
        case .x: return ([0, 1, 0], [0, 0, 1])   // плоскость YZ
        case .y: return ([1, 0, 0], [0, 0, 1])   // плоскость XZ
        case .z: return ([1, 0, 0], [0, 1, 0])   // плоскость XY
        }
    }
}
