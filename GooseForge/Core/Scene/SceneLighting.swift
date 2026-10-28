//
//  SceneLighting.swift
//  ECSRenderer
//
//  Created by Igorchela on 13.08.2026.
//

import MetalKit

struct SceneLighting {
    
    let sunlight: Light = {
        var light = Self.buildDefaultLight()
        light.position = [0, 10, -30]
        light.color = [0.949, 1.0, 0.863]
        light.intensity = 1.0
        light.radius = 1
        return light
    }()
    
    
    static func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = float3(repeating: 1.0)
        light.intensity = 1.0
        light.specularColor = float3(repeating: 0.6)
        light.attenuation = [1, 0, 0]
        light.type = Sun
        return light
    }
}
