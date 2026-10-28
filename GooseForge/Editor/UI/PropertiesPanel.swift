//
//  PropertiesPanel.swift
//  GooseForge
//
//  Created by Igorchela on 19.10.2026.
//

import SwiftUI

struct PropertiesPanel: View {
    let state: EditorState
    
    var body: some View {
        // Оборачиваем всё в ScrollView, чтобы если экран маленький — можно было прокрутить
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let scene = state.scene, let selected = scene.selectedEntity {
                    
                    // --- 1. БЛОК ТРАНСФОРМАЦИИ ---
                    Text("Transform").font(.headline)
                    positionSection(entity: selected)
                    rotationSection(entity: selected)
                    scaleSection(entity: selected)
                    
                    Divider().padding(.vertical, 8)
                    
                    // --- 2. БЛОК МАТЕРИАЛОВ ---
                    Text("Material").font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // 1. Меню для BaseColor (Цвет)
                        Menu("Set Base Color") {
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: BaseColor) }
                            }
                        }
                        // 2. Меню для Normal (Нормали)
                        Menu("Set Normal Map") {
                            Button("None (Remove)") { scene.applyTexture(name: "", type: NormalTexture) }
                            Divider()
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: NormalTexture) }
                            }
                        }
                        // 3. Меню для Roughness (Шероховатость)
                        Menu("Set Roughness") {
                            Button("None (Remove)") { scene.applyTexture(name: "", type: RoughnessTexture) }
                            Divider()
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: RoughnessTexture) }
                            }
                        }
                        // 4. Меню для AO (Затенение)
                        Menu("Set AO") {
                            Button("None (Remove)") { scene.applyTexture(name: "", type: AOTexture) }
                            Divider()
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: AOTexture) }
                            }
                        }
                        
                        // 5. Меню для Metalic
                        Menu("Set Metalic") {
                            Button("None (Remove)") { scene.applyTexture(name: "", type: MetallicTexture) }
                            Divider()
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: MetallicTexture) }
                            }
                        }
                        
                        // 6. Меню для Opacity (Прозрачность)
                        Menu("Set Opacity") {
                            Button("None (Remove)") { scene.applyTexture(name: "", type: OpacityTexture) }
                            Divider()
                            ForEach(scene.availableTextures(), id: \.self) { tex in
                                Button(tex) { scene.applyTexture(name: tex, type: OpacityTexture) }
                            }
                        }
                        
                    }
                    .menuStyle(.borderlessButton) // Делает меню компактными
                    .frame(maxWidth: 200, alignment: .leading)
                    
                } else {
                    Text("No entity selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer() // Прижимает контент к верху
            }
            .padding()
        }
        .frame(width: 450, alignment: .leading)
        .background(.ultraThinMaterial)
    }
    
    private func positionSection(entity: Entity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Position").font(.caption).bold()
            HStack(spacing: 6) {
                FloatInput(label: "X", entity: entity, state: state,
                           get: { $0.position.x }, set: { $0.position.x = $1 })
                FloatInput(label: "Y", entity: entity, state: state,
                           get: { $0.position.y }, set: { $0.position.y = $1 })
                FloatInput(label: "Z", entity: entity, state: state,
                           get: { $0.position.z }, set: { $0.position.z = $1 })
            }
        }
    }
    
    private func rotationSection(entity: Entity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rotation (rad)").font(.caption).bold()
            HStack(spacing: 6) {
                FloatInput(label: "X", entity: entity, state: state,
                           get: { eulerYXZ(from: $0.rotationQuat).x },
                           set: { t, v in
                    var e = eulerYXZ(from: t.rotationQuat)
                    e.x = v
                    t.rotationQuat = quatFromEulerYXZ(e)
                })
                FloatInput(label: "Y", entity: entity, state: state,
                           get: { eulerYXZ(from: $0.rotationQuat).y },
                           set: { t, v in
                    var e = eulerYXZ(from: t.rotationQuat)
                    e.y = v
                    t.rotationQuat = quatFromEulerYXZ(e)
                })
                FloatInput(label: "Z", entity: entity, state: state,
                           get: { eulerYXZ(from: $0.rotationQuat).z },
                           set: { t, v in
                    var e = eulerYXZ(from: t.rotationQuat)
                    e.z = v
                    t.rotationQuat = quatFromEulerYXZ(e)
                })
            }
        }
    }
    
    private func scaleSection(entity: Entity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scale").font(.caption).bold()
            HStack(spacing: 6) {
                FloatInput(label: "X", entity: entity, state: state,
                           get: { $0.scaleVec.x },
                           set: { t, v in t.scaleVec.x = max(0.001, v) })
                FloatInput(label: "Y", entity: entity, state: state,
                           get: { $0.scaleVec.y },
                           set: { t, v in t.scaleVec.y = max(0.001, v) })
                FloatInput(label: "Z", entity: entity, state: state,
                           get: { $0.scaleVec.z },
                           set: { t, v in t.scaleVec.z = max(0.001, v) })
            }
        }
    }
}


    // MARK: - Универсальное поле

struct FloatInput: View {
    let label: String
    let entity: Entity
    let state: EditorState
    let get: (TransformComponent) -> Float
    let set: (inout TransformComponent, Float) -> Void
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            if !label.isEmpty {
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 55)
                .focused($isFocused)
                .onAppear { syncFromManager() }
                .onSubmit { commit() }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onChange(of: entity) { _, _ in
                    text = ""
                    syncFromManager()
                }
        }
    }
    
    private func syncFromManager() {
        guard let t = state.entityManager.getComponent(for: entity) as TransformComponent? else { return }
        let v = get(t)
        text = format(v)
    }
    
    private func format(_ v: Float) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.3f", v)
    }
    
    private func commit() {
        print("🟢 commit text='\(text)'")
        guard let v = Float(text) else {
            print("🔴 parse failed")
            syncFromManager()
            return
        }
        var t = state.entityManager.getComponent(for: entity) as TransformComponent? ?? TransformComponent()
        set(&t, v)
        state.entityManager.addComponent(component: t, to: entity)
    }
    
    
}

