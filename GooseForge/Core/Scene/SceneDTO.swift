//
//  SceneDTO.swift
//  GooseEngine
//
//  Created by Igorchela on 12.10.2026.
//

import Foundation

struct SceneFile: Codable {
    var version:    Int
    var camera:     CameraDTO
    var lights:     [LightDTO]?
    var entities:   [EntityDTO]?
}

struct CameraDTO: Codable {
    var name:       String?
    var position:   [Float]
    var rotation:   [Float]
}

struct LightDTO: Codable {
    var name:        String?
    var type:        String                  // "sun" | "point" | "spot" | "ambient"
    var position:    [Float]
    var color:       [Float]
    var intensity:    Float
    var castsShadows: Bool = false
    var radius:       Float?
    var attenuation: [Float]?
}


struct EntityDTO: Codable {
    var name:               String?
    var model:              String                          // "primitive:plane" или "house1.usdz"
    var position:           [Float] = [0, 0, 0]
    var rotation:           [Float] = [0, 0, 0]          // радианы
    var scale:              [Float] = [0, 0, 0]
    var tiling:             UInt32?
    var roughness:          Float?
    var metallic:           Float?
    var ambientOcclusion:   Float?
    var opacity:            Float?
    
    var baseColorTextureMap:   String?
    var normalTextureMap:      String?
    var roughnessTextureMap:   String?
    var aoTextureMap:          String?
    var metalicTextureMap:      String?
    var opacityTextureMap:     String?
}
