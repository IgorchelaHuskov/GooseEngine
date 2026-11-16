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
              let activeCamera = manager.getComponent(for: scene.activeCameraID) as FPCameraComponent?,
              let cameraTransform = manager.getComponent(for: scene.activeCameraID) as TransformComponent?,
              let (_, sunPosition) = manager.query(LightComponent.self).first(where: { $0.a.castsShadows }) as (Entity, LightComponent)?,
              let shadowC = manager.getComponent(for: shadowID) as ShadowCameraComponent?,
              let shadowT = manager.getComponent(for: shadowID) as TransformComponent?
        else { return }

        // ★ КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: центр — позиция игрока (в FPS игрок = камера)
        let camPos = cameraTransform.position

        // (опционально) сдвиг чуть вперёд — тени становятся резче в той стороне,
        // куда смотрит игрок. Но для начала достаточно и чистого camPos.
        // let forward = cameraTransform.rotationQuat.act(float3(0, 0, 1))
        // let shadowCenter = camPos + forward * (maxShadowDistance * 0.5)
        let shadowCenter = camPos

        let viewSize = maxShadowDistance   // = 40

        let sunDir = normalize(sunPosition.light.position)

        var shadowCamera = shadowC
        var shadowTransform = shadowT
        shadowCamera.near = 0.01
        shadowCamera.far  = viewSize * 2 + 10   // небольшой запас на диагональ
        shadowCamera.viewSize = CGFloat(viewSize)
        shadowCamera.center = shadowCenter

        let rawEye = shadowCenter + sunDir * viewSize

        // Texel snapping (как было)
        let up: float3 = abs(sunDir.y) > 0.99 ? float3(0, 0, 1) : float3(0, 1, 0)
        let lightView = float4x4(eye: rawEye, target: shadowCenter, up: up)

        let texel = viewSize / Float(shadowCamera.mapSize)
        var centerLS = (lightView * float4(shadowCenter, 1)).xyz
        centerLS.x = round(centerLS.x / texel) * texel
        centerLS.y = round(centerLS.y / texel) * texel

        let snappedCenterWS = (lightView.inverse * float4(centerLS, 1)).xyz
        let delta = snappedCenterWS - shadowCenter

        shadowCamera.center = shadowCenter + delta
        shadowCamera.up = up
        shadowTransform.position = rawEye + delta

        manager.addComponent(component: shadowCamera, to: shadowID)
        manager.addComponent(component: shadowTransform, to: shadowID)
    }
}
