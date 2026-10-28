//
//  EntityProxy.swift
//  ECSRenderer
//
//  Created by Igorchela on 12.08.2026.
//

import simd
import MetalKit

@dynamicMemberLookup
struct EntityProxy {
    let id: Entity
    let manager: EntityManager
    
    // Перехватываем обращение к свойствам TransformComponent напрямую!
    subscript<T>(dynamicMember dynamicMember: WritableKeyPath<TransformComponent, T>) -> T {
        get {
            let transform = manager.getComponent(for: id) as TransformComponent? ?? TransformComponent()
            return transform[keyPath: dynamicMember]
        }
        nonmutating set {
            var transform = manager.getComponent(for: id) as TransformComponent? ?? TransformComponent()
            transform[keyPath: dynamicMember] = newValue
            manager.addComponent(component: transform, to: id)
        }
    }
    
    // Если нужно быстро получить доступ к MaterialComponent
    var material: MaterialComponent? {
        get { manager.getComponent(for: id) }
        nonmutating set {
            if let newValue = newValue {
                manager.addComponent(component: newValue, to: id)
            }
        }
    }
    
    /// Euler YXZ. Только для UI и загрузки сцены, не для рантайма.
    var eulerRotation: float3 {
        get {
            let t = manager.getComponent(for: id) as TransformComponent? ?? TransformComponent()
            return eulerYXZ(from: t.rotationQuat)
        }
        nonmutating set {
            var t = manager.getComponent(for: id) as TransformComponent? ?? TransformComponent()
            t.rotationQuat = quatFromEulerYXZ(newValue)
            manager.addComponent(component: t, to: id)
        }
    }
    
    func setTexture(name: String, type: TextureIndices, device: MTLDevice) {
        var material = manager.getComponent(for: id) as MaterialComponent? ?? MaterialComponent(textures: Submesh.Textures())
        material.setTexture(name: name, type: type, device: device)
        manager.addComponent(component: material, to: id)
    }
}



