//
//  OrthoCameraSystem.swift
//  ECSRenderer
//
//  Created by Igorchela on 17.08.2026.
//

import Foundation

struct ShadowCameraSystem: System {
    // Сколько метров вокруг игрока покрываем тенями.
    // Больше — тени на большую дистанцию, но мыльнее.
    // 30–50 — хороший компромисс для FPS/TPS.
    private let maxShadowDistance: Float = 100

    func update(manager: EntityManager, scene: SceneManager, size: CGSize) {}

    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float) {
        guard let shadowID = scene.shadowCameraID,
              let (_, sunPosition) = manager.query(LightComponent.self).first(where: { $0.a.castsShadows }),
              let shadowC = manager.getComponent(for: shadowID) as ShadowCameraComponent?,
              let shadowT = manager.getComponent(for: shadowID) as TransformComponent?
        else { return }

        // 1. Ищем позицию игрока. Если игрока нет — берем активную камеру.
        var centerPos: float3? = nil
        
        if let playerEntity = manager.query(PlayerComponent.self).first?.entity,
           let playerTransform = manager.getComponent(for: playerEntity) as TransformComponent? {
            // Нашли игрока — центрируем тени на нем
            centerPos = playerTransform.position
        } else if let camTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent? {
            // Нет игрока — центрируем на камере (например, в режиме редактора)
            centerPos = camTransform.position
        }
        
        // Если ни игрока, ни камеры — выходим
        guard let camPos = centerPos else { return }

        // 2. Настраиваем параметры теней
        let viewSize = maxShadowDistance
        let sunDir = normalize(sunPosition.light.position)

        var shadowCamera = shadowC
        var shadowTransform = shadowT
        shadowCamera.near = 0.01
        shadowCamera.far = viewSize * 2 + 10
        shadowCamera.viewSize = CGFloat(viewSize)
        shadowCamera.center = camPos

        let rawEye = camPos + sunDir * viewSize
        let up: float3 = abs(sunDir.y) > 0.99 ? float3(0, 0, 1) : float3(0, 1, 0)
        let lightView = float4x4(eye: rawEye, target: camPos, up: up)

        // 3. Texel Snapping (чтобы тени не мерцали при движении)
        let texel = viewSize / Float(shadowCamera.mapSize)
        var centerLS = (lightView * float4(camPos, 1)).xyz
        centerLS.x = round(centerLS.x / texel) * texel
        centerLS.y = round(centerLS.y / texel) * texel

        let snappedCenterWS = (lightView.inverse * float4(centerLS, 1)).xyz
        let delta = snappedCenterWS - camPos

        shadowCamera.center = camPos + delta
        shadowCamera.up = up
        shadowTransform.position = rawEye + delta

        manager.addComponent(component: shadowCamera, to: shadowID)
        manager.addComponent(component: shadowTransform, to: shadowID)
    }
}
