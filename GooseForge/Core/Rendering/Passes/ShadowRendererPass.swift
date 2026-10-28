//
//  ShadowRendererPass.swift
//  ECSRenderer
//
//  Created by Igorchela on 15.08.2026.
//

import MetalKit

struct ShadowRendererPass: RenderPass {
    let label: String = "Shadow Render Pass"
    var descriptor: MTLRenderPassDescriptor? = MTLRenderPassDescriptor()
    var depthStencilState: MTLDepthStencilState? = Self.buildDepthStencilState()
    var pipelineState: MTLRenderPipelineState
    var shadowTexture: MTLTexture?

    init() {
      pipelineState = PipelineStates.createShadowPSO()
      shadowTexture = Self.makeTexture(size: CGSize(width: 2048, height: 2048),
                                       pixelFormat: Renderer.viewDepthPixelFormat,
                                       label: "Shadow Depth Texture")
    }

    
    func resize(view: MTKView, size: CGSize) {}
    
    func draw(commandBuffer: MTLCommandBuffer, manager: EntityManager, scene: SceneManager, uniforms: Uniforms, params: Params) {
        guard let descriptor = descriptor else { return }
        descriptor.depthAttachment.texture = shadowTexture
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        renderEncoder.label = "Shadow Encoder"
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        var uniforms = uniforms
        
        for (entity, meshComponent, materialComponent) in manager.query(MeshComponent.self, MaterialComponent.self) {
            let submesh = meshComponent.meshes.submeshes[meshComponent.submeshesIndex]
                
            if submesh.transparency || materialComponent.isTransparent { continue }
            
            uniforms.modelMatrix = manager.worldMatrix(for: entity)
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: UniformsBuffer.index)
            
            let meshes = meshComponent.meshes
            for (index, vertexBuffer) in meshes.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: index)
            }
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer,
                                                indexBufferOffset: submesh.indexBufferOffset)
            
        }
        
        renderEncoder.endEncoding()
    }
}
