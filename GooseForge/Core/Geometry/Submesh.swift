//
//  Submesh.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

struct Submesh {
    let indexCount: Int
    let indexType: MTLIndexType
    let indexBuffer: MTLBuffer
    let indexBufferOffset: Int
    
    struct Textures {
        var baseColor: MTLTexture?
        var normal: MTLTexture?
        var roughness: MTLTexture?
        var metallic: MTLTexture?
        var ambientOcclusion: MTLTexture?
        var opacity: MTLTexture?
    }
    var textures: Textures
    var material: Material
    
    var transparency: Bool {
        return textures.opacity != nil || material.opacity < 1.0
    }
}

extension Submesh {
    init(mdlSubmesh: MDLSubmesh, mtkSubmesh: MTKSubmesh, device: MTLDevice) {
        indexCount = mtkSubmesh.indexCount
        indexType = mtkSubmesh.indexType
        indexBuffer = mtkSubmesh.indexBuffer.buffer
        indexBufferOffset = mtkSubmesh.indexBuffer.offset
        textures = Textures(material: mdlSubmesh.material, device: device)
        material = Material(material: mdlSubmesh.material)
    }
}

private extension Submesh.Textures {
    init(material: MDLMaterial?, device: MTLDevice) {
        baseColor = material?.texture(type: .baseColor, device: device)
        normal = material?.texture(type: .tangentSpaceNormal, device: device)
        roughness = material?.texture(type: .roughness, device: device)
        metallic = material?.texture(type: .metallic, device: device)
        ambientOcclusion = material?.texture(type: .ambientOcclusion, device: device)
        opacity = material?.texture(type: .opacity, device: device)
    }
}

private extension MDLMaterialProperty {
    var textureName: String {
        stringValue ?? UUID().uuidString
    }
}

private extension MDLMaterial {
    func texture(type semantic: MDLMaterialSemantic, device: MTLDevice) -> MTLTexture? {
        if let property = property(with: semantic),
           property.type == .texture,
           let mdlTexture = property.textureSamplerValue?.texture {
            var texture = TextureController.loadTexture(
                texture: mdlTexture,
                name: property.textureName, device: device)
            if semantic == .baseColor,
               texture?.pixelFormat == .rgba8Unorm {
                texture = texture?.makeTextureView(pixelFormat: .rgba8Unorm_srgb)
                TextureController.textures[property.textureName] = texture
            }
            return texture
        }
        return nil
    }
}

private extension Material {
    init(material: MDLMaterial?) {
        self.init()
        if let baseColor = material?.property(with: .baseColor),
           baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }
        ambientOcclusion = 1
        if let roughness = material?.property(with: .roughness),
           roughness.type == .float {
            self.roughness = roughness.floatValue
        }
        if let metallic = material?.property(with: .metallic),
           metallic.type == .float {
            self.metallic = metallic.floatValue
        }
        opacity = 1.0
        if let opacity = material?.property(with: .opacity) {
            switch opacity.type {
            case .float:  self.opacity = opacity.floatValue
            case .float3: self.opacity = opacity.float3Value.x
            default:      break
            }
        }
    }
}

