//
//  OrthoCameraSystem.swift
//  ECSRenderer
//
//  Created by Igorchela on 17.08.2026.
//

import Foundation

struct ShadowCameraSystem: System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {
        if let shadowCamera = scene.shadowCameraID {
            guard var cameraComponent = manager.getComponent(for: shadowCamera) as ShadowCameraComponent? else { fatalError() }
            cameraComponent.aspect = size.width / size.height
            manager.addComponent(component: cameraComponent, to: shadowCamera)
        }
    }
    
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        guard scene.shadowCameraID != nil else { return }
        guard let activeCamera = manager.getComponent(for: scene.activeCameraID) as FPCameraComponent?,
              let cameraTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent? else { fatalError() }
        
        
        guard let (_, sunPosition) = manager.query(LightComponent.self).first(where: { $0.a.castsShadows }) else { return }
        
        let rotationMatrix = float4x4(cameraTransform.rotationQuat)
        let translationMat = float4x4(translation: cameraTransform.position)
        
        let playerViewMatrix = (translationMat * rotationMatrix).inverse
        let playerProjectionMatrix = activeCamera.projectionMatrix
        
        let viewProjection = playerProjectionMatrix * playerViewMatrix
        let (frustumCentr, frustumRadius) = viewProjection.boundingSphere()
        
        let direction = normalize(sunPosition.light.position)
        let newShadowPosition = frustumCentr + direction * frustumRadius
        
        if let shadowCameraID = scene.shadowCameraID {
            guard let shadowC = manager.getComponent(for: shadowCameraID) as ShadowCameraComponent?,
                  let shadowT = manager.getComponent(for: shadowCameraID) as TransformComponent? else { fatalError() }
            
            var shadowCamera = shadowC
            var shadowTransform = shadowT
            
            shadowCamera.near = 0.01
            shadowCamera.far  = frustumRadius * 2
            shadowCamera.viewSize = CGFloat(frustumRadius * 2)   // явно от радиуса, не от far
            shadowCamera.center = frustumCentr
            shadowTransform.position = newShadowPosition
            manager.addComponent(component: shadowCamera, to: shadowCameraID)
            manager.addComponent(component: shadowTransform, to: shadowCameraID)
        }
    }
    
}
