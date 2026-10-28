//
//  TiledRenderPass.swift
//  ECSRenderer
//
//  Created by Igorchela on 15.09.2026.
//

import MetalKit

struct TiledRenderPass: RenderPass {
    let label: String = "Tiled Render Pass"
    let depthStencilState:              MTLDepthStencilState?
    let lightingDepthStencilState:      MTLDepthStencilState?
    let transparentDepthStencilState:   MTLDepthStencilState?
    
    var descriptor:             MTLRenderPassDescriptor?
    var gBufferPSO:             MTLRenderPipelineState
    var iblPSO:                 MTLRenderPipelineState
    var sunLightPSO:            MTLRenderPipelineState
    var pointLightPSO:          MTLRenderPipelineState
    var transparentForwardPSO:  MTLRenderPipelineState
    
    var albedoTexture:      MTLTexture?
    var normalTexture:      MTLTexture?
    var positionTexture:    MTLTexture?
    var depthTexture:       MTLTexture?
    var auxTexture:         MTLTexture?
    var idTexture:          MTLTexture?
    
    weak var shadowTexture: MTLTexture?
    
    var overlays: [TiledPassOverlay] = []
    
    init(view: MTKView) {
        gBufferPSO              = PipelineStates.createGBufferPSO()
        iblPSO                  = PipelineStates.createIBL_PSO()
        pointLightPSO           = PipelineStates.createPointLightPSO()
        transparentForwardPSO   = PipelineStates.createForwardTransparentTiledPSO()
        sunLightPSO             = PipelineStates.createDeferredSunPSO()
        
        depthStencilState               = Self.buildDepthStencilState()
        lightingDepthStencilState       = Self.buildLightingDepthStencilState()
        transparentDepthStencilState    = Self.buildTransparentDepthStencilState()
    }
    
    static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        let frontFaceStencil = MTLStencilDescriptor()
        frontFaceStencil.stencilCompareFunction = .always
        frontFaceStencil.stencilFailureOperation = .keep
        frontFaceStencil.depthFailureOperation = .keep
        frontFaceStencil.depthStencilPassOperation = .incrementClamp
        
        let backFaceStencil = MTLStencilDescriptor()
        backFaceStencil.stencilCompareFunction = .always
        backFaceStencil.stencilFailureOperation = .keep
        backFaceStencil.depthFailureOperation = .keep
        backFaceStencil.depthStencilPassOperation = .incrementClamp
        
        descriptor.backFaceStencil = backFaceStencil
        descriptor.frontFaceStencil = frontFaceStencil
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
    static func buildLightingDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = false
        
        let frontFaceStencil = MTLStencilDescriptor()
        frontFaceStencil.stencilCompareFunction = .notEqual
        frontFaceStencil.stencilFailureOperation = .keep
        frontFaceStencil.depthFailureOperation = .keep
        frontFaceStencil.depthStencilPassOperation = .keep
        
        let backFaceStencil = MTLStencilDescriptor()
        backFaceStencil.stencilCompareFunction = .always
        backFaceStencil.stencilFailureOperation = .keep
        backFaceStencil.depthFailureOperation = .keep
        backFaceStencil.depthStencilPassOperation = .incrementClamp
        
        descriptor.backFaceStencil = backFaceStencil
        descriptor.frontFaceStencil = frontFaceStencil
        
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
    static func buildTransparentDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled  = false
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
    mutating func resize(view: MTKView, size: CGSize) {
        self.albedoTexture   = Self.makeTexture(size: size, pixelFormat: .bgra8Unorm, label: "Albedo Texture", storageMode: .memoryless)
        self.normalTexture   = Self.makeTexture(size: size, pixelFormat: .rgba16Float, label: "Normal Texture", storageMode: .memoryless)
        self.positionTexture = Self.makeTexture(size: size, pixelFormat: .rgba16Float, label: "Position Texture", storageMode: .memoryless)
        self.depthTexture    = Self.makeTexture(size: size, pixelFormat: .depth32Float_stencil8, label: "Depth Texture", storageMode: .memoryless)
        self.auxTexture      = Self.makeTexture(size: size, pixelFormat: .rgba8Unorm, label: "Aux Texture", storageMode: .memoryless)
        self.idTexture       = Self.makeTexture(size: size, pixelFormat: .r32Uint, label: "Entity ID Texture", storageMode: .private)
    }
    
    func draw(commandBuffer: any MTLCommandBuffer, manager: EntityManager, scene: SceneManager, uniforms: Uniforms, params: Params) {
        guard let viewCurrentRenderPassDescriptor = descriptor else { fatalError() }
        let descriptor = viewCurrentRenderPassDescriptor
        let texrures = [albedoTexture, normalTexture, positionTexture, auxTexture]
        
        if let idTexture {
            let idAttachment = descriptor.colorAttachments[RenderTargetEntityID.index]
            idAttachment?.texture = idTexture
            idAttachment?.loadAction = .clear
            idAttachment?.storeAction = .store
            idAttachment?.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        
        for (index, texture) in texrures.enumerated() {
            let attachment = descriptor.colorAttachments[RenderTargetAlbedo.index + index]
            attachment?.texture = texture
            attachment?.loadAction = .clear
            attachment?.storeAction = .dontCare
            attachment?.clearColor = MTLClearColor(red: 0.73, green: 0.92, blue: 1, alpha: 1)
        }
        
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.stencilAttachment.texture = depthTexture
        descriptor.stencilAttachment.storeAction = .dontCare
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        drawGBufferRenderPass (renderEncoder: renderEncoder, manager: manager, scene: scene, uniforms: uniforms, params: params)
        drawLightingRenderPass(renderEncoder: renderEncoder, manager: manager, scene: scene, uniforms: uniforms, params: params)
        
        if let skybox = scene.skyBox {
            skybox.render(encoder: renderEncoder, uniforms: uniforms)
        }
        
        drawTransparentPass(renderEncoder: renderEncoder, manager: manager, scene: scene, uniforms: uniforms, params: params)
        
        for overlay in overlays {
            overlay.render(encoder: renderEncoder, scene: scene, uniforms: uniforms, params: params)
        }
        renderEncoder.endEncoding()
    }
    
    func drawGBufferRenderPass(renderEncoder: MTLRenderCommandEncoder, manager: EntityManager, scene: SceneManager, uniforms: Uniforms, params: Params) {
        var uniforms = uniforms
        var params   = params
    
        params.selectedEntityID = scene.selectedEntity.map { $0 + 1 } ?? 0
        
        renderEncoder.label = "Tiled G-buffer render pass"
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(gBufferPSO)
        if let shadowTexture { renderEncoder.setFragmentTexture(shadowTexture, index: ShadowTexture.index) }
        
        for (entity, meshComponent, materialComponent) in manager.query(MeshComponent.self, MaterialComponent.self) {
            
            var entityId = manager.rootEntity(for: entity).map { UInt32($0) + 1 } ?? (entity + 1)
            params.tiling = materialComponent.tiling
            uniforms.modelMatrix = manager.worldMatrix(for: entity)
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            
            renderEncoder.setVertexBytes  (&uniforms, length: MemoryLayout<Uniforms>.stride, index: UniformsBuffer.index)
            renderEncoder.setFragmentBytes(&params,   length: MemoryLayout<Params>.stride,   index: ParamsBuffer.index)
            renderEncoder.setFragmentBytes(&entityId, length: MemoryLayout<UInt32>.stride,   index: EntityIDBuffer.index)
            
            let meshes = meshComponent.meshes
            for (index, vertexBuffer) in meshes.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: index)
            }
            
            let submesh = meshes.submeshes[meshComponent.submeshesIndex]
            if submesh.transparency || materialComponent.isTransparent { continue }
            
            var material = materialComponent.material
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: MaterialBuffer.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.baseColor, index: BaseColor.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.roughness, index: RoughnessTexture.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.normal, index: NormalTexture.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.metallic, index: MetallicTexture.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.ambientOcclusion, index: AOTexture.index)
            renderEncoder.setFragmentTexture(materialComponent.textures.opacity, index: OpacityTexture.index)
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer,
                                                indexBufferOffset: submesh.indexBufferOffset)
            
        }
    }
    
    func drawLightingRenderPass(renderEncoder: MTLRenderCommandEncoder, manager: EntityManager, scene: SceneManager, uniforms: Uniforms, params: Params) {
        var uniforms = uniforms
        
        renderEncoder.label = "Tiled Lighting render pass"
        renderEncoder.setDepthStencilState(lightingDepthStencilState)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: UniformsBuffer.index)
        
        drawIBL(renderEncoder: renderEncoder, scene: scene, params: params)
        drawSunLight(renderEncoder: renderEncoder, scene: scene, params: params)
        drawPointLight(renderEncoder: renderEncoder, manager: manager, scene: scene, paraps: params)
    }
    
    private func drawIBL(renderEncoder: MTLRenderCommandEncoder, scene: SceneManager, params: Params) {
        scene.skyBox?.update(encoder: renderEncoder)
        var params = params
    
        renderEncoder.pushDebugGroup("Ibl Light")
        renderEncoder.setRenderPipelineState(iblPSO)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Params>.stride, index: ParamsBuffer.index)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.popDebugGroup()
    }
    
    private func drawPointLight(renderEncoder: MTLRenderCommandEncoder, manager: EntityManager, scene: SceneManager, paraps: Params) {
        guard !scene.pointLights.isEmpty else { return }
        var params = paraps
        params.lightCount = UInt32(scene.pointLights.count)
        
        renderEncoder.pushDebugGroup("Point Lights")
        renderEncoder.setRenderPipelineState(pointLightPSO)
        
        renderEncoder.setVertexBuffer(scene.pointBuffer, offset: 0, index: LightBuffer.index)
        renderEncoder.setFragmentBuffer(scene.pointBuffer, offset: 0, index: LightBuffer.index)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Params>.stride, index: ParamsBuffer.index)
        
        guard let meshComponent = manager.getComponent(for: scene.icosahedron) as MeshComponent? else { return }
        let meshes = meshComponent.meshes
        let submesh = meshes.submeshes[meshComponent.submeshesIndex]
        for (index, vertexBuffer) in meshes.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: index)
        }
        
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer,
                                            indexBufferOffset: submesh.indexBufferOffset,
                                            instanceCount: scene.pointLights.count)
        renderEncoder.popDebugGroup()
    }
    
    private func drawSunLight(renderEncoder: MTLRenderCommandEncoder, scene: SceneManager, params: Params) {
        guard !scene.sunLights.isEmpty else { return }
        var params = params
        params.lightCount = UInt32(scene.sunLights.count)
        
        renderEncoder.pushDebugGroup("Sun Light")
        renderEncoder.setRenderPipelineState(sunLightPSO)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Params>.stride, index: ParamsBuffer.index)
        renderEncoder.setFragmentBuffer(scene.sunBuffer, offset: 0, index: LightBuffer.index)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.popDebugGroup()
    }
    
    private func drawTransparentPass(renderEncoder: MTLRenderCommandEncoder,
                                     manager: EntityManager,
                                     scene: SceneManager,
                                     uniforms: Uniforms,
                                     params: Params) {
        var uniforms = uniforms
        var params = params
        params.transparency = true
        
        renderEncoder.label = "Transparent forward pass"
        renderEncoder.setDepthStencilState(transparentDepthStencilState)  // write OFF
        renderEncoder.setRenderPipelineState(transparentForwardPSO)       // blend ON
        
        // 1. Собрать только прозрачные
        var entities: [(entity: Entity, mesh: MeshComponent, material: MaterialComponent)] = []
        
        for (entity, mesh, material) in manager.query(
            MeshComponent.self, MaterialComponent.self) {
            
            let submesh = mesh.meshes.submeshes[mesh.submeshesIndex]
            let isTransparent = submesh.transparency || material.isTransparent
            guard isTransparent else { continue }
            
            entities.append((entity, mesh, material))
        }
        
        // 2. Отсортировать back-to-front
        let eye = params.cameraPosition
        entities.sort {
            let wa = manager.worldMatrix(for: $0.entity)
            let wb = manager.worldMatrix(for: $1.entity)
            let pa = wa.columns.3
            let pb = wb.columns.3
            let da = simd_distance_squared(SIMD3(pa.x, pa.y, pa.z), eye)
            let db = simd_distance_squared(SIMD3(pb.x, pb.y, pb.z), eye)
            if da != db { return da > db }
            return $0.entity < $1.entity
        }
        
        // 3. Отрисовать
        for (entity, mesh, material) in entities {
            params.tiling         = material.tiling
            uniforms.modelMatrix  = manager.worldMatrix(for: entity)
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride,
                                         index: UniformsBuffer.index)
            renderEncoder.setFragmentBytes(&params, length: MemoryLayout<Params>.stride,
                                           index: ParamsBuffer.index)
            
            for (index, vb) in mesh.meshes.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vb, offset: 0, index: index)
            }
            
            var mat = material.material
            renderEncoder.setFragmentBytes(&mat, length: MemoryLayout<Material>.stride,
                                           index: MaterialBuffer.index)
            if let sky = scene.skyBox {
                sky.update(encoder: renderEncoder)
            }
            renderEncoder.setFragmentTexture(shadowTexture, index: ShadowTexture.index)
            
            let t = material.textures
            renderEncoder.setFragmentTexture(t.baseColor,        index: BaseColor.index)
            renderEncoder.setFragmentTexture(t.roughness,        index: RoughnessTexture.index)
            renderEncoder.setFragmentTexture(t.normal,           index: NormalTexture.index)
            renderEncoder.setFragmentTexture(t.metallic,         index: MetallicTexture.index)
            renderEncoder.setFragmentTexture(t.ambientOcclusion, index: AOTexture.index)
            renderEncoder.setFragmentTexture(t.opacity,          index: OpacityTexture.index)
            if let shadowTexture { renderEncoder.setFragmentTexture(shadowTexture, index: ShadowTexture.index) }
            
            // Света — тоже нужно передать, transparent forward использует fragment_main
            renderEncoder.setFragmentBuffer(scene.lightsBuffer, offset: 0, index: LightBuffer.index)
            
            let submesh = mesh.meshes.submeshes[mesh.submeshesIndex]
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer,
                                                indexBufferOffset: submesh.indexBufferOffset)
        }
    }
    
    /// Возвращает ID сущности под указанной точкой (в координатах вью, top-left)
    /// Синхронно — только для клика, не для каждого кадра!
    func readEntityID(at point: CGPoint) -> Entity? {
        guard let idTexture else { return nil }

        let sx = Int(point.x * Renderer.scaleFactor)
        let sy = Int(point.y * Renderer.scaleFactor)
        guard sx >= 0, sy >= 0, sx < idTexture.width, sy < idTexture.height else { return nil }

        let bufferLength = MemoryLayout<UInt32>.stride
        guard let readback = Renderer.device.makeBuffer(length: bufferLength, options: .storageModeShared),
              let cmd = Renderer.commandQueue.makeCommandBuffer(),
              let blit = cmd.makeBlitCommandEncoder() else { return nil }

        blit.copy(from: idTexture,
                  sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: sx, y: sy, z: 0),
                  sourceSize: MTLSize(width: 1, height: 1, depth: 1),
                  to: readback,
                  destinationOffset: 0,
                  destinationBytesPerRow: bufferLength,
                  destinationBytesPerImage: bufferLength)
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()      // ← стоп-кадр на ~1 мс, только по клику

        let raw = readback.contents().load(as: UInt32.self)
        return raw == 0 ? nil : Entity(raw - 1)   // откатываем +1
    }
}

