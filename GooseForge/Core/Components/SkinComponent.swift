//
//  SkinComponent.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import MetalKit

struct SkinComponent: Component {
    // Связь костей меша со скелетом
    let skinToSkeletonMap: [Int]
    
    // Буфер, который мы скормим видеокарте в шейдере
    let jointMatrixPaletteBuffer: MTLBuffer
}
