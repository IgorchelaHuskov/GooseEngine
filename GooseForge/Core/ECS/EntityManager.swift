//
//  EntityManager.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//
// Решение на будущее = архетипы, но это когда реально упрусь в производительность с физикой на десятках тысяч тел.

import Foundation

typealias Entity = UInt32

class EntityManager {
    private var nextEntityID: Entity = 0
    private var components: [ObjectIdentifier: [Entity: Any]] = [:]
    
    func createEntity() -> Entity {
        let id = nextEntityID
        nextEntityID += 1
        return id
    }
    
    func addComponent<C: Component>(component: C, to entity: Entity) {
        let key = ObjectIdentifier(C.self)
        if components[key] == nil { components[key] = [:] }
        components[key]?[entity] = component
    }
    
    func getComponent<C: Component>(for entity: Entity) -> C? {
        let key = ObjectIdentifier(C.self)
        return components[key]?[entity] as? C
    }
    
    func getAllComponents<C: Component>() -> [Entity: C] {
        let key = ObjectIdentifier(C.self)
        return (components[key] as? [Entity: C]) ?? [:]
    }
    
    func removeEntity(_ entity: Entity) {
        // 1. Отвязываем от родителя
        if let transform = getComponent(for: entity) as TransformComponent?,
           let parent = transform.parent {
            if var parentChildren = getComponent(for: parent) as ChildrenComponent? {
                parentChildren.children.removeAll { $0 == entity }
                addComponent(component: parentChildren, to: parent)
            }
        }
        
        // 2. Рекурсивно удаляем детей (чтобы не осталось "сирот")
        if let childrenComp = getComponent(for: entity) as ChildrenComponent? {
            for child in childrenComp.children {
                removeEntity(child)
            }
        }
        
        // 3. Удаляем все компоненты самой сущности
        // Используем Array(components.keys), чтобы безопасно изменять словарь
        for key in Array(components.keys) {
            components[key]?.removeValue(forKey: entity)
        }
    }
}

// MARK: - Queries
extension EntityManager {
    /// Достаём сырое хранилище по типу компонента.
    private func storage<C: Component>(_ type: C.Type) -> [Entity: C] {
        return (components[ObjectIdentifier(C.self)] as? [Entity: C]) ?? [:]
    }
    
    /// Все сущности с одним компонентом.
    func query<A: Component>(_ typeA: A.Type) -> [(entity: Entity, a: A)] {
        let dictA = storage(A.self)
        return dictA.map { ($0.key, $0.value) }
    }
    
    /// Все сущности, у которых есть оба компонента A и B.
    func query<A: Component, B: Component>(_ typeA: A.Type,
                                           _ typeB: B.Type) -> [(entity: Entity, a: A, b: B)] {
        let dictA = storage(A.self)
        let dictB = storage(B.self)
        // Итерируем по меньшему словарю — так быстрее.
        if dictA.count <= dictB.count {
            return dictA.compactMap { (entity, a) in
                guard let b = dictB[entity] else { return nil }
                return (entity, a, b)
            }
        } else {
            return dictB.compactMap { (entity, b) in
                guard let a = dictA[entity] else { return nil }
                return (entity, a, b)
            }
        }
    }
    
    /// Все сущности с тремя компонентами.
    func query<A: Component, B: Component, C: Component>(_ typeA: A.Type,
                                                         _ typeB: B.Type,
                                                         _ typeC: C.Type) -> [(entity: Entity, a: A, b: B, c: C)] {
        let dictA = storage(A.self)
        let dictB = storage(B.self)
        let dictC = storage(C.self)
        return dictA.compactMap { (entity, a) in
            guard let b = dictB[entity], let c = dictC[entity] else { return nil }
            return (entity, a, b, c)
        }
    }
    
    /// Все сущности с четырьмя компонентами.
    func query<A: Component, B: Component, C: Component, D: Component>(_ typeA: A.Type,
                                                                       _ typeB: B.Type,
                                                                       _ typeC: C.Type,
                                                                       _ typeD: D.Type) -> [(entity: Entity, a: A, b: B, c: C, d: D)] {
        let dictA = storage(A.self)
        let dictB = storage(B.self)
        let dictC = storage(C.self)
        let dictD = storage(D.self)
        return dictA.compactMap { (entity, a) in
            guard let b = dictB[entity],
                  let c = dictC[entity],
                  let d = dictD[entity] else { return nil }
            return (entity, a, b, c, d)
        }
    }
}

extension EntityManager {
    func proxy(for entity: Entity) -> EntityProxy {
        return EntityProxy(id: entity, manager: self)
    }
}

extension EntityManager {
    /// Находит или создаёт ChildrenComponent и добавляет ребёнка.
    func attach(child: Entity, to parent: Entity) {
        // 1. У ребёнка — parent
        var transformParent = getComponent(for: child) as TransformComponent? ?? TransformComponent()
        transformParent.parent = parent
        addComponent(component: transformParent, to: child)
        
        // 2. У родителя — children
        var childComponent = getComponent(for: parent) as ChildrenComponent? ?? ChildrenComponent()
        if !childComponent.children.contains(child) {
            childComponent.children.append(child)
        }
        addComponent(component: childComponent, to: parent)
    }
    
    /// Отсоединяет ребёнка (не удаляя), опционально — с сохранением мировой позиции.
    func detach(child: Entity, keepWorldTransform: Bool = false) {
        guard let transformParent = getComponent(for: child) as TransformComponent?,
              let parent = transformParent.parent else { return }
        
        var newTransformParent = transformParent
        if keepWorldTransform {
            // Мировая позиция = worldMatrix родителя * локальная позиция
            let parentWorld = worldMatrix(for: parent)
            let world = parentWorld * float4(transformParent.position, 1)
            newTransformParent.position = world.xyz
            
            // rotation/scale тоже надо преобразовать — упрощённо оставим как есть,
            // точный случай с отрицательным scale и ненулевым поворотом родителя
            // требует разложения матрицы. 
        }
        
        newTransformParent.parent = nil
        addComponent(component: newTransformParent, to: child)
        
        if var childComponent = getComponent(for: parent) as ChildrenComponent? {
            childComponent.children.removeAll() { $0 == child }
            addComponent(component: childComponent, to: parent)
        }
    }
    
    /// Мировая матрица для рендера. Считается от корня вниз.
    func worldMatrix(for entity: Entity) -> float4x4 {
        guard let transform = getComponent(for: entity) as TransformComponent? else {
            return .identity
        }
        
        let local = float4x4(translation: transform.position) *
                    float4x4(transform.rotationQuat) *
                    float4x4(scaling: transform.scaleVec)
        
        if let parent = transform.parent {
            return worldMatrix(for: parent) * local
        }
        
        return local
    }
    
    /// Идём вверх по parent до корня.
    func rootEntity(for entity: Entity) -> Entity? {
        var current = entity
        while let t = getComponent(for: current) as TransformComponent?,
              let parent = t.parent {
            current = parent
        }
        return current
    }
    
    /// Получить всех детей
    /// Прямые дети сущности.
    func children(of entity: Entity) -> [Entity] {
        (getComponent(for: entity) as ChildrenComponent?)?.children ?? []
    }
    
    /// Все потомки рекурсивно (если понадобится на глубоких иерархиях).
    func descendants(of entity: Entity) -> [Entity] {
        var result: [Entity] = []
        for child in children(of: entity) {
            result.append(child)
            result.append(contentsOf: descendants(of: child))
        }
        return result
    }
    
    /*
     У меня сейчас два режима работы с миром трансформов, и путать их нельзя.
     
     Режим A — «чисто и просто». worldMatrix(for:) рекурсивно каждый раз при рендере. Работает для маленьких сцен (< 100 объектов). Просто, корректно, но при 1000 объектах — квадратичная сложность из-за повторов рекурсии.
     
     Режим B — «кэш». Раз в кадр проходишь по иерархии от корней вниз, считаешь worldMatrix каждой сущности, кладёшь в кэш [Entity: float4x4]. При рендере берёшь из кэша. Это то, что делают все нормальные движки.
     
     Для начала сделаю A. Когда упрусь в FPS — введу B.
     */
}

extension EntityManager {
    /// Глубокое клонирование сущности со всеми компонентами и детьми.
    func duplicate(entity: Entity) -> Entity {
        let newEntity = createEntity()
        
        // 1. Копируем Transform (родителя пока отвязываем, привяжем при необходимости)
        if var transform = getComponent(for: entity) as TransformComponent? {
            transform.parent = nil
            addComponent(component: transform, to: newEntity)
        }
        
        // 2. Копируем Mesh
        if let mesh = getComponent(for: entity) as MeshComponent? {
            addComponent(component: mesh, to: newEntity)
        }
        
        // 3. Копируем Material
        if let material = getComponent(for: entity) as MaterialComponent? {
            addComponent(component: material, to: newEntity)
        }
        
        // 4. Копируем Light (если это источник света)
        if let light = getComponent(for: entity) as LightComponent? {
            addComponent(component: light, to: newEntity)
        }
        
        // 5. Рекурсивно копируем детей
        if let childrenComp = getComponent(for: entity) as ChildrenComponent? {
            for child in childrenComp.children {
                let newChild = duplicate(entity: child)
                attach(child: newChild, to: newEntity)
            }
        }
        
        return newEntity
    }
}
