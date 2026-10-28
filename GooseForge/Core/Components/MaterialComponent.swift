//
//  MaterialComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

struct MaterialComponent: Component {
    var textures: Submesh.Textures
    var material: Material = Material()
    var tiling: UInt32 = 1
    var isTransparent: Bool = false
    
    var baseColorTextureName:   String? = nil
    var normalTextureName:      String? = nil
    var roughnessTextureName:   String? = nil
    var aoTextureName:          String? = nil
    var metalicTextreName:      String? = nil
    var opacityTextureName:     String? = nil
}

extension MaterialComponent {
    mutating func setTexture(name: String, type: TextureIndices, device: MTLDevice) {
        let isColorTexture = (type == BaseColor)
        if let texture = TextureController.loadTexture(name: name, device: device, isSRGB: isColorTexture) {
            switch type {
            case BaseColor:             self.textures.baseColor         = texture
                                        self.baseColorTextureName       = name
                
            case NormalTexture:         self.textures.normal            = texture
                                        self.normalTextureName          = name
                
            case RoughnessTexture:      self.textures.roughness         = texture
                                        self.roughnessTextureName       = name
                
            case MetallicTexture:       self.textures.metallic          = texture
                                        self.metalicTextreName          = name
                
            case AOTexture:             self.textures.ambientOcclusion  = texture
                                        self.aoTextureName              = name
                
            case OpacityTexture:        self.textures.opacity           = texture
                                        self.opacityTextureName         = name
            default:                    break
            }
        }
    }
}
