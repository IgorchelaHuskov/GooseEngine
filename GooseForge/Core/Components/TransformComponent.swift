//
//  TransformComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import Foundation
import simd

struct TransformComponent: Component {
    var position: float3 = .zero
    var rotationQuat: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    var scaleVec: SIMD3<Float> = .one
    var parent: Entity? = nil
    
    var scale: Float {
        get { scaleVec.x }
        set { scaleVec = .init(repeating: newValue) }
    }
}
