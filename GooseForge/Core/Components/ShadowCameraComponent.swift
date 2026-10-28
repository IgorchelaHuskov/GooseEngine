//
//  OrtoCameraComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 15.08.2026.
//

import CoreGraphics

struct ShadowCameraComponent: Component {
    var aspect: CGFloat = 1
    var viewSize: CGFloat = 10
    var near: Float = 0.1
    var far: Float = 25
    var center = float3.zero
    
    var projectionMatrix: float4x4 {
        let rect = CGRect(x: -viewSize * aspect * 0.5,
                          y: viewSize * 0.5,
                          width: viewSize * aspect,
                          height: viewSize)
        return float4x4(orthographic: rect, near: near, far: far)
    }
}
