//
//  ContentView.swift
//  GooseForge
//
//  Created by Igorchela on 19.10.2026.
//

import SwiftUI

struct ContentView: View {
    @State var options = Options()
    @State var editor = EditorState()
    
    var body: some View {
        HStack(spacing: 16) {
            MetalView(options: options, editor: editor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.black))
                .cornerRadius(12)
            
            Divider()
            
            // Правая панель управления с фиксированной шириной
            VStack(spacing: 20) {
                PropertiesPanel(state: editor)
                
                HStack {
                    Button("Add Cube") { editor.scene?.addPrimitive(.cube) }
                    Button("Add Sphere") { editor.scene?.addPrimitive(.sphere) }
                    Button("Add Plane") { editor.scene?.addPrimitive(.plane) }
                }
                
                // Меню добавления USDZ моделей ---
                if let scene = editor.scene {
                    Menu("Add Model from Bundle") {
                        ForEach(scene.availableModels(), id: \.self) { modelName in
                            Button(modelName) {
                                // Вызываем метод, который мы написали ранее
                                scene.addModel(named: modelName)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 200)
                }
                
                
                
                Divider()
                Button("Save Scene") {
                    guard let scene = editor.scene else { return }
                    
                    // Сохраняем в папку Документы (потому что Bundle только для чтения)
                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    let docDirectory = paths[0]
                    let saveURL = docDirectory.appendingPathComponent("saved_scene.json")
                    
                    do {
                        try SceneSaver.save(scene: scene, manager: editor.entityManager, to: saveURL)
                        print("Сцена сохранена по пути: \(saveURL)")
                    } catch {
                        print("Ошибка сохранения: \(error)")
                    }
                }
            }
            .frame(width: 450) // Чуть увеличили ширину для читаемости
        }
        .padding() // Внешний отступ от краев окна
    }
}


