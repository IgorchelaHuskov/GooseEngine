//
//  TiledPassOverlay.swift
//  GooseForge
//
//  Created by Igorchela on 18.10.2026.
//

import MetalKit

/// Слой, который рисуется поверх готовой сцены (после непрозрачных
/// и прозрачных объектов). Реализуется в редакторе (гизмо, сетка,
/// подсветка), но тип объявлен в движке — `TiledRenderPass` должен
/// знать про него, чтобы хранить массив `overlays`.
protocol TiledPassOverlay {
    func render(encoder: MTLRenderCommandEncoder,
                scene: SceneManager,
                uniforms: Uniforms,
                params: Params)
}
