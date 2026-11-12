//
//  Pipelines.swift
//  ECSRenderer
//
//  Created by Igorchela on 15.08.2026.
//

import MetalKit

enum PipelineStates {
    static func createPSO(descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        let pipelineState: MTLRenderPipelineState
        do { pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: descriptor) } catch {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
    
    static func createComputePSO(function: String) -> MTLComputePipelineState {
        guard let kernel = Renderer.library.makeFunction(name: function) else { fatalError("Unable to create \(function) PSO") }
        let pipelineState: MTLComputePipelineState
        do {
            pipelineState = try Renderer.device.makeComputePipelineState(function: kernel)
        } catch {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
    
    static func makeFunctionConstants(hasSkeleton: Bool) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()
        var property = hasSkeleton
        functionConstants.setConstantValue(&property, type: .bool, index: 0)
        return functionConstants
    }
    
    static func createShadowPSO() -> MTLRenderPipelineState {
        let vertexFunction = Renderer.library?.makeFunction(name: "vertex_depth")
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        pipelineDescriptor.depthAttachmentPixelFormat = Renderer.viewDepthPixelFormat
        pipelineDescriptor.vertexDescriptor = .defaultLayout
        
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createGBufferPSO(hasSkeleton: Bool = false) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(hasSkeleton: hasSkeleton)
        let vertexFunction = try? Renderer.library?.makeFunction(name: "vertex_main",  constantValues: functionConstants)
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_gBuffer")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.vertexDescriptor = MTLVertexDescriptor.defaultLayout

        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createIBL_PSO() -> MTLRenderPipelineState {
        let vertexFunction = Renderer.library?.makeFunction(name: "vertex_quad")
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_IBL")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].writeMask = []
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createDeferredSunPSO() -> MTLRenderPipelineState {

        let vertexFunction = Renderer.library?.makeFunction(name: "vertex_quad")
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_deferredSun")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].writeMask = []
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        let attachment = pipelineDescriptor.colorAttachments[0]
        attachment?.isBlendingEnabled           = true
        attachment?.rgbBlendOperation           = .add
        attachment?.sourceRGBBlendFactor        = .one
        attachment?.destinationRGBBlendFactor   = .one
        attachment?.alphaBlendOperation         = .add
        attachment?.sourceAlphaBlendFactor      = .zero
        attachment?.destinationAlphaBlendFactor = .one
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createPointLightPSO() -> MTLRenderPipelineState {
        let vertexFunction = Renderer.library?.makeFunction(name: "vertex_pointLight")
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_pointLight")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].writeMask = []
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.vertexDescriptor = MTLVertexDescriptor.defaultLayout
        
        let attachment = pipelineDescriptor.colorAttachments[0]
        attachment?.isBlendingEnabled = true
        attachment?.rgbBlendOperation = .add
        attachment?.alphaBlendOperation = .add
        attachment?.sourceRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .one
        attachment?.destinationAlphaBlendFactor = .zero
        attachment?.sourceRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .zero
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createForwardTransparentTiledPSO(hasSkeleton: Bool) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(hasSkeleton: hasSkeleton)
        let vertexFunction = try? Renderer.library?.makeFunction(name: "vertex_main",  constantValues: functionConstants)
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_transparent")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction   = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = .defaultLayout
        
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].writeMask = []
        
        pipelineDescriptor.depthAttachmentPixelFormat   = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        // blend — только на attachment 0
        let attachment = pipelineDescriptor.colorAttachments[0]
        attachment?.isBlendingEnabled           = true
        attachment?.rgbBlendOperation           = .add
        attachment?.sourceRGBBlendFactor        = .sourceAlpha
        attachment?.destinationRGBBlendFactor   = .oneMinusSourceAlpha
        
        // attachments 1,2,3 не пишутся — говорим Metal'у явно
        pipelineDescriptor.colorAttachments[1].writeMask = []
        pipelineDescriptor.colorAttachments[2].writeMask = []
        pipelineDescriptor.colorAttachments[3].writeMask = []
        pipelineDescriptor.colorAttachments[4].writeMask = []
        
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createSkyboxPSO(vertexDescriptor: MTLVertexDescriptor?) -> MTLRenderPipelineState {
        let vertexFunction = Renderer.library?.makeFunction(name: "vertex_skybox")
        let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_skybox")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        
        // Attachments 1, 2, 3 — G-buffer, форматы совпадают, но НЕ пишем
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].writeMask = []
        pipelineDescriptor.colorAttachments[1].writeMask = []
        pipelineDescriptor.colorAttachments[2].writeMask = []
        pipelineDescriptor.colorAttachments[3].writeMask = []
        pipelineDescriptor.colorAttachments[4].writeMask = []
        
        // Depth + stencil — как в TiledRenderPass
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        return createPSO(descriptor: pipelineDescriptor)
    }
    
    static func createGizmoPSO() -> MTLRenderPipelineState {
        let vertexFunction = Renderer.library.makeFunction(name: "vertex_gizmo")
        let fragmentFunction = Renderer.library.makeFunction(name: "fragment_gizmo")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction   = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        let vd = MTLVertexDescriptor()
        
        // Position (индекс 0)
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        
        // Color (индекс 1)
        vd.attributes[1].format = .float3
        // ВАЖНО: В Swift SIMD3<Float> занимает 16 байт из-за выравнивания!
        // Поэтому цвет начинается не с 12-го, а с 16-го байта.
        vd.attributes[1].offset = 16
        vd.attributes[1].bufferIndex = 0
        
        // Общий размер одной вершины в Swift = 32 байта (два SIMD3 по 16 байт)
        vd.layouts[0].stride = 32
        
        pipelineDescriptor.vertexDescriptor = vd
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.viewColorPixelFormat
        pipelineDescriptor.setGBufferPixelFormat()
        pipelineDescriptor.colorAttachments[RenderTargetEntityID.index].pixelFormat = .r32Uint
        pipelineDescriptor.colorAttachments[RenderTargetNormal.index].writeMask   = []
        pipelineDescriptor.colorAttachments[RenderTargetPosition.index].writeMask = []
        pipelineDescriptor.colorAttachments[RenderTargetAux.index].writeMask      = []

        pipelineDescriptor.depthAttachmentPixelFormat   = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8

        return createPSO(descriptor: pipelineDescriptor)
    }
}

extension MTLRenderPipelineDescriptor {
    func setGBufferPixelFormat() {
        colorAttachments[RenderTargetAlbedo.index].pixelFormat = .bgra8Unorm
        colorAttachments[RenderTargetNormal.index].pixelFormat = .rgba16Float
        colorAttachments[RenderTargetPosition.index].pixelFormat = .rgba16Float
        colorAttachments[RenderTargetAux.index].pixelFormat      = .rgba8Unorm
    }
}
