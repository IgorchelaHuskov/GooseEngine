//
//  Render.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

class Renderer: NSObject {
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    static var viewColorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    static var viewDepthPixelFormat = MTLPixelFormat.depth32Float
    static var scaleFactor: CGFloat = 1
    
    var uniforms = Uniforms()
    var params = Params()
    var shadowRenderPass: ShadowRendererPass
    var tiledRenderPass: TiledRenderPass
    
    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { fatalError("GPU not available") }
        
        Self.device = device
        Self.commandQueue = commandQueue
        metalView.device = device
        metalView.colorPixelFormat = Self.viewColorPixelFormat
        Self.scaleFactor = NSScreen.main?.backingScaleFactor ?? 1
        
        let library = device.makeDefaultLibrary()
        Self.library = library
        
        shadowRenderPass = ShadowRendererPass()
        tiledRenderPass = TiledRenderPass(view: metalView)
        
        super.init()
        metalView.clearColor = MTLClearColor(red: 0.4,
                                             green: 0.4,
                                             blue: 1.0,
                                             alpha: 1.0)
        metalView.depthStencilPixelFormat = .depth32Float
        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        shadowRenderPass.resize(view: view, size: size)
        tiledRenderPass.resize(view: view, size: size)
        
        params.width = UInt32(size.width)
        params.height = UInt32(size.height)
    }
    
    func updateUniforms(manager: EntityManager, scene: SceneManager ) {
        params.alphaTesting = true
        guard let activeCameraComponent = manager.getComponent(for: scene.activeCameraID) as FPCameraComponent?,
              let activeCameracameraTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent? else { return }
        
        let rotationMatrix = float4x4(activeCameracameraTransform.rotationQuat)
            let translationMat = float4x4(translation: activeCameracameraTransform.position)
            let viewMatrix = (translationMat * rotationMatrix).inverse
            uniforms.viewMatrix = viewMatrix
            uniforms.projectionMatrix = activeCameraComponent.projectionMatrix

            params.lightCount = UInt32(scene.allLights.count)
            params.cameraPosition = activeCameracameraTransform.position
        
        if let shadowID = scene.shadowCameraID,
           let shadowComponent = manager.getComponent(for: shadowID) as ShadowCameraComponent?,
           let shadowTransform = manager.getComponent(for: shadowID) as TransformComponent? {
            uniforms.shadowProjectionMatrix = shadowComponent.projectionMatrix
            uniforms.shadowViewMatrix = float4x4(eye: shadowTransform.position,
                                                 target: shadowComponent.center,
                                                 up: [0, 1, 0])
            params.shadowsEnabled = true
        } else {
            uniforms.shadowProjectionMatrix = .identity
            uniforms.shadowViewMatrix = .identity
            params.shadowsEnabled = false
        }
    }
    
    func draw(in view: MTKView, manager: EntityManager, scene: SceneManager) {
        guard let commandBuffer = Self.commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        updateUniforms(manager: manager, scene: scene)
        
        if scene.shadowCameraID != nil {
            shadowRenderPass.draw(commandBuffer: commandBuffer, manager: manager, scene: scene, uniforms: uniforms, params: params)
            tiledRenderPass.shadowTexture = shadowRenderPass.shadowTexture
        } else {
            tiledRenderPass.shadowTexture = nil
        }
        
        tiledRenderPass.descriptor = descriptor
        tiledRenderPass.draw(commandBuffer: commandBuffer, manager: manager, scene: scene, uniforms: uniforms, params: params)
       

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
