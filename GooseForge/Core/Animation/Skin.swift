//
//  Skin.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import MetalKit

struct Skin {
    var jointPaths: [String] = []
    var skinToSkeletonMap: [Int] = []
    var jointMatrixPaletteBuffer: MTLBuffer
    
    init?(animationBindComponent: MDLAnimationBindComponent?, skeleton: SkeletonComponent?) {
        guard let animationBindComponent, let skeleton else { return nil }
        jointPaths = animationBindComponent.jointPaths ?? skeleton.jointPaths
        skinToSkeletonMap = skeleton.mapJoints(from: jointPaths)
        
        let bufferSize = jointPaths.count * MemoryLayout<float4x4>.stride
        guard let paletteBuffer = Renderer.device.makeBuffer(length: bufferSize) else {
            fatalError("Unable to create buffer")
        }
        jointMatrixPaletteBuffer = paletteBuffer
    }
}
