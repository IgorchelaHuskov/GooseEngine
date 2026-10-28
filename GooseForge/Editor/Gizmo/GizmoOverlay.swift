//
//  GizmoOverlay.swift
//  GooseForge
//
//  Created by Igorchela on 21.10.2026.
//

import MetalKit
import simd
internal import GameController

private struct GizmoVertex {
    var position: SIMD3<Float>
    var color:    SIMD3<Float>
}

enum GizmoMode { case translate, rotate, scale }

final class GizmoOverlay: TiledPassOverlay {
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState?
    
    // Статичный буфер для геометрии цилиндра
    private let cylinderBuffer: MTLBuffer
    private let cylinderVertexCount: Int
    
    private let ringBuffer: MTLBuffer
    private let ringVertexCount: Int
    
    private let scaleStemBuffer: MTLBuffer
    private let scaleStemVertexCount: Int
    
    private let cubeBuffer:      MTLBuffer
    private let cubeVertexCount: Int
    
    private var hoveredAxis: GizmoAxis? = nil
    
    private var activeAxis: GizmoAxis? = nil
    private var wasMouseDownLastFrame: Bool = false
    
    // состояние «заморожено в момент захвата»
    private var dragAxisWorldDir:     SIMD3<Float>? = nil
    private var dragPlaneOrigin:      SIMD3<Float>? = nil
    private var dragPlaneNormal:      SIMD3<Float>? = nil
    private var dragStartWorldPivot:  SIMD3<Float>? = nil
    private var dragStartScaleVec:    SIMD3<Float>? = nil
    private var dragStartAxisParam:   Float = 0
    private var dragEntity:           Entity? = nil
    
    private static let cylinderHeight: Float = 0.5
    private static let cylinderRadius: Float = 0.015
    private static let coneHeight:     Float = 0.2
    private static let coneRadius:     Float = 0.06
    
    private static var localLength: Float { cylinderHeight + coneHeight }
    private static var shaftFraction: Float { cylinderHeight / localLength }

    
    // state для rotate-drag
    private var rotateStartQuat:   simd_quatf? = nil
    private var rotateStartVector: SIMD3<Float>? = nil
    private var rotatePrevAngle:   Float = 0
    private var rotateAccumulated: Float = 0
    private var rotateAxisDir:     SIMD3<Float>? = nil
    
    
    var mode: GizmoMode = .translate

    init() {
        pipelineState = PipelineStates.createGizmoPSO()

        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = .always
        d.isDepthWriteEnabled  = false
        depthStencilState = Renderer.device.makeDepthStencilState(descriptor: d)
        
        // Вызываем обновленный метод геометрии:
        // Древко длиной 0.8 (радиус 0.02), Наконечник длиной 0.2 (радиус 0.05)
        let cylinderVerts = GizmoOverlay.generateCylinder(radialSegments: 20, // Сделаем чуть круглее
                                                          cylinderHeight: 0.5,
                                                          cylinderRadius: 0.015,
                                                          coneHeight: 0.2,
                                                          coneRadius: 0.06
        )
        self.cylinderVertexCount = cylinderVerts.count
        
        let length = MemoryLayout<GizmoVertex>.stride * cylinderVertexCount
        self.cylinderBuffer = Renderer.device.makeBuffer(
            bytes: cylinderVerts,
            length: length,
            options: .storageModeShared
        )!
        
        let ringVerts = GizmoOverlay.generateRing(
            majorSegments: 48,
            minorSegments: 10,
            majorRadius: 0.7,
            minorRadius: 0.03
        )
        self.ringVertexCount = ringVerts.count

        let ringByteLength = MemoryLayout<GizmoVertex>.stride * ringVertexCount
        self.ringBuffer = Renderer.device.makeBuffer(
            bytes: ringVerts,
            length: ringByteLength,
            options: .storageModeShared
        )!
        let stemVerts = GizmoOverlay.generateCylinderStem(
            radialSegments: 20,
            height: GizmoOverlay.localLength,   // 0.7
            radius: GizmoOverlay.cylinderRadius
        )
        self.scaleStemVertexCount = stemVerts.count
        self.scaleStemBuffer = Renderer.device.makeBuffer(
            bytes: stemVerts,
            length: MemoryLayout<GizmoVertex>.stride * stemVerts.count,
            options: .storageModeShared
        )!

        let cubeVerts = GizmoOverlay.generateCube(size: 0.06)
        self.cubeVertexCount = cubeVerts.count
        self.cubeBuffer = Renderer.device.makeBuffer(
            bytes: cubeVerts,
            length: MemoryLayout<GizmoVertex>.stride * cubeVerts.count,
            options: .storageModeShared
        )!
    }

    func render(encoder: MTLRenderCommandEncoder,
                scene: SceneManager,
                uniforms: Uniforms,
                params: Params) {
        guard let selected = scene.selectedEntity,
              scene.manager.getComponent(for: selected) as TransformComponent? != nil
        else { return }
        
        // переключение по клавишам W/E (как в Unity) — временно
        if InputController.shared.keysPressed.contains(.keyR) { mode = .rotate }
        if InputController.shared.keysPressed.contains(.keyT) { mode = .translate }
        if InputController.shared.keysPressed.contains(.keyY) { mode = .scale }
        
        let world = scene.manager.worldMatrix(for: selected)
        let origin = SIMD3<Float>(world.columns.3.x, world.columns.3.y, world.columns.3.z)
        
        let gizmoLength: Float = 3.0
        let gizmoScale: Float = 3.0
        let worldLength = Self.localLength * gizmoScale   // 2.1
        
        encoder.pushDebugGroup("Gizmo Overlay")
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthStencilState)
        
        switch mode {
        case .translate:
            updateHover(origin: origin, worldLength: worldLength,
                        gizmoScale: gizmoScale, mode: .translate, uniforms: uniforms, params: params)
            
            updateDragState(origin: origin, scene: scene,
                            uniforms: uniforms, params: params, mode: .translate)
            
            if activeAxis != nil {
                updateDrag(scene: scene, uniforms: uniforms, params: params)
            }
            
            drawTranslateGizmo(encoder: encoder, origin: origin,
                               gizmoLength: gizmoLength, gizmoScale: gizmoScale,
                               uniforms: uniforms,
                               highlight: activeAxis ?? hoveredAxis)
            
        case .rotate:
            updateHover(origin: origin, worldLength: worldLength,
                        gizmoScale: gizmoScale, mode: .rotate,
                        uniforms: uniforms, params: params)
            
            updateDragState(origin: origin, scene: scene,
                            uniforms: uniforms, params: params, mode: .rotate)   // ← новое
            
            if activeAxis != nil {
                updateRotateDrag(scene: scene, uniforms: uniforms, params: params) // ← новое
            }
            
            drawRotateGizmo(encoder: encoder, origin: origin,
                            gizmoScale: gizmoScale,
                            uniforms: uniforms,
                            highlight: activeAxis ?? hoveredAxis)
        case .scale:
            updateHover(origin: origin, worldLength: worldLength,
                        gizmoScale: gizmoScale, mode: .scale,
                        uniforms: uniforms, params: params)
            updateDragState(origin: origin, scene: scene,
                            uniforms: uniforms, params: params, mode: .scale)
            if activeAxis != nil {
                updateScaleDrag(scene: scene, uniforms: uniforms, params: params)
            }
            drawScaleGizmo(encoder: encoder, origin: origin,
                           gizmoScale: gizmoScale, uniforms: uniforms,
                           highlight: activeAxis ?? hoveredAxis)
        }
        
        encoder.popDebugGroup()
    }
    
    private func drawTranslateGizmo(encoder: MTLRenderCommandEncoder,
                                    origin: SIMD3<Float>,
                                    gizmoLength: Float,
                                    gizmoScale: Float,
                                    uniforms: Uniforms,
                                    highlight: GizmoAxis?) {
        encoder.setVertexBuffer(cylinderBuffer, offset: 0, index: 0)
        
        for axis in GizmoAxis.allCases {
            let scaleMatrix = float4x4(scaling: [gizmoScale, gizmoLength, gizmoScale])
            let modelMatrix = float4x4(translation: origin) * axis.rotation * scaleMatrix
            
            var axisUniforms = uniforms
            axisUniforms.modelMatrix = modelMatrix
            encoder.setVertexBytes(&axisUniforms,
                                   length: MemoryLayout<Uniforms>.stride,
                                   index: UniformsBuffer.index)
            
            var color = (axis == highlight) ? axis.hoverColor : axis.baseColor
            encoder.setFragmentBytes(&color,
                                     length: MemoryLayout<SIMD4<Float>>.stride,
                                     index: 0)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                   vertexCount: cylinderVertexCount)
            
        }
    }

    private func drawRotateGizmo(encoder: MTLRenderCommandEncoder,
                                 origin: SIMD3<Float>,
                                 gizmoScale: Float,
                                 uniforms: Uniforms,
                                 highlight: GizmoAxis?) {
        encoder.setVertexBuffer(ringBuffer, offset: 0, index: 0)

        for axis in GizmoAxis.allCases {
            // Кольцо уже в локальных координатах радиусом 0.7.
            // Масштаб равномерный: [s, s, s] — кольца не вытягиваются.
            let scaleMatrix = float4x4(scaling: [gizmoScale, gizmoScale, gizmoScale])
            let modelMatrix = float4x4(translation: origin) * axis.rotation * scaleMatrix

            var axisUniforms = uniforms
            axisUniforms.modelMatrix = modelMatrix
            encoder.setVertexBytes(&axisUniforms,
                                   length: MemoryLayout<Uniforms>.stride,
                                   index: UniformsBuffer.index)

            var color = (axis == highlight) ? axis.hoverColor : axis.baseColor
            encoder.setFragmentBytes(&color,
                                     length: MemoryLayout<SIMD4<Float>>.stride,
                                     index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                   vertexCount: ringVertexCount)
        }
    }
    
    private func drawScaleGizmo(encoder: MTLRenderCommandEncoder,
                                 origin: SIMD3<Float>,
                                 gizmoScale: Float,
                                 uniforms: Uniforms,
                                 highlight: GizmoAxis?) {
        let worldLength = Self.localLength * gizmoScale

        // 1. Стержни (цилиндры без конуса)
        encoder.setVertexBuffer(scaleStemBuffer, offset: 0, index: 0)
        for axis in GizmoAxis.allCases {
            let scaleM = float4x4(scaling: [gizmoScale, gizmoScale, gizmoScale])
            let model  = float4x4(translation: origin) * axis.rotation * scaleM
            var u = uniforms
            u.modelMatrix = model
            encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: UniformsBuffer.index)
            var color = (axis == highlight) ? axis.hoverColor : axis.baseColor
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: scaleStemVertexCount)
        }

        // 2. Кубики на концах
        encoder.setVertexBuffer(cubeBuffer, offset: 0, index: 0)
        for axis in GizmoAxis.allCases {
            let tip = origin + axis.direction * worldLength
            let scaleM = float4x4(scaling: [gizmoScale, gizmoScale, gizmoScale])
            let model  = float4x4(translation: tip) * scaleM
            var u = uniforms
            u.modelMatrix = model
            encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: UniformsBuffer.index)
            var color = (axis == highlight) ? axis.hoverColor : axis.baseColor
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: cubeVertexCount)
        }
    }
    
    private func beginRotateDrag(axis: GizmoAxis, origin: SIMD3<Float>,
                                  entity: Entity, scene: SceneManager,
                                  uniforms: Uniforms, params: Params) {
        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor,
                                              viewSize: viewSize,
                                              uniforms: uniforms)
        else { return }

        // Плоскость кольца = плоскость вращения. Нормаль = ось.
        let planeNormal = axis.direction
        guard let hit0 = GizmoHitTest.rayPlaneIntersection(ray: ray,
                                                            planePoint: origin,
                                                            planeNormal: planeNormal)
        else { return }

        let v0 = simd_normalize(hit0 - origin)
        guard simd_length_squared(v0) > 1e-6 else { return }

        rotateStartVector = v0
        rotatePrevAngle   = 0
        rotateAccumulated = 0
        rotateAxisDir     = axis.direction

        let transform = scene.manager.getComponent(for: entity) as TransformComponent?
                     ?? TransformComponent()
        rotateStartQuat = transform.rotationQuat
        dragEntity      = entity

        InputController.shared.gizmoCaptured = true
        print("beginRotate axis=\(axis) v0=\(v0)")
    }

    private func updateRotateDrag(scene: SceneManager,
                                   uniforms: Uniforms, params: Params) {
        guard let v0 = rotateStartVector,
              let axisDir = rotateAxisDir,
              let startQuat = rotateStartQuat,
              let entity = dragEntity
        else { return }

        // Пересчитываем origin от сущности — на случай, если объект сместили
        let world = scene.manager.worldMatrix(for: entity)
        let origin = SIMD3<Float>(world.columns.3.x, world.columns.3.y, world.columns.3.z)

        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor,
                                              viewSize: viewSize,
                                              uniforms: uniforms),
              let hit = GizmoHitTest.rayPlaneIntersection(ray: ray,
                                                          planePoint: origin,
                                                          planeNormal: axisDir)
        else { return }

        let v1 = simd_normalize(hit - origin)
        guard simd_length_squared(v1) > 1e-6 else { return }

        // Угол между v0 и v1 вокруг axisDir (знаковый, через cross)
        let cross = simd_dot(simd_cross(v0, v1), axisDir)
        let dotP  = simd_dot(v0, v1)
        let rawAngle = atan2(cross, dotP)   // -π..π

        // Unwrap: если прыжок через ±π — корректируем
        var delta = rawAngle - rotatePrevAngle
        if delta >  .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        rotateAccumulated += delta
        rotatePrevAngle   = rawAngle

        // Применяем: мировое вращение = deltaQuat * startQuat (кватернионы!)
        let dq = simd_quatf(angle: rotateAccumulated, axis: axisDir)
        let newQuat = simd_normalize(dq * startQuat)

        var transform = scene.manager.getComponent(for: entity) as TransformComponent?
                     ?? TransformComponent()
        transform.rotationQuat = newQuat
        scene.manager.addComponent(component: transform, to: entity)

        print("rawAngle=\(rawAngle) acc=\(rotateAccumulated)")
    }
    
    private func beginScaleDrag(axis: GizmoAxis, origin: SIMD3<Float>,
                                 entity: Entity, scene: SceneManager,
                                 uniforms: Uniforms, params: Params) {
        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor, viewSize: viewSize, uniforms: uniforms)
        else { return }

        let axisDir = axis.direction
        let camPos = SIMD3<Float>(uniforms.viewMatrix.inverse.columns.3.x,
                                  uniforms.viewMatrix.inverse.columns.3.y,
                                  uniforms.viewMatrix.inverse.columns.3.z)
        let camToGizmo = origin - camPos
        let camPerp = camToGizmo - axisDir * simd_dot(axisDir, camToGizmo)
        let camPerpLen = simd_length(camPerp)
        guard camPerpLen > 1e-4 else { return }
        let planeNormalN = camPerp / camPerpLen

        guard let hit0 = GizmoHitTest.rayPlaneIntersection(ray: ray, planePoint: origin,
                                                            planeNormal: planeNormalN)
        else { return }

        dragAxisWorldDir   = axisDir
        dragPlaneOrigin    = origin
        dragPlaneNormal    = planeNormalN
        dragStartAxisParam = simd_dot(hit0 - origin, axisDir)
        dragEntity         = entity

        let transform = scene.manager.getComponent(for: entity) as TransformComponent?
                     ?? TransformComponent()
        dragStartScaleVec = transform.scaleVec

        InputController.shared.gizmoCaptured = true
    }

    private func updateScaleDrag(scene: SceneManager,
                                  uniforms: Uniforms, params: Params) {
        guard let axisDir = dragAxisWorldDir,
              let planeOrigin = dragPlaneOrigin,
              let planeNormal = dragPlaneNormal,
              let entity = dragEntity,
              let startScale = dragStartScaleVec
        else { return }

        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor, viewSize: viewSize, uniforms: uniforms),
              let hit = GizmoHitTest.rayPlaneIntersection(ray: ray, planePoint: planeOrigin,
                                                          planeNormal: planeNormal)
        else { return }

        let sNow  = simd_dot(hit - planeOrigin, axisDir)
        let delta = sNow - dragStartAxisParam

        let worldLength: Float = Self.localLength * 3.0   // совпадает с gizmoScale=3.0
        let ratio = max(0.01, 1.0 + delta / worldLength)   // не даём уйти в 0

        var newScale = startScale
        switch axisDir {
        case SIMD3<Float>(1, 0, 0): newScale.x = startScale.x * ratio
        case SIMD3<Float>(0, 1, 0): newScale.y = startScale.y * ratio
        case SIMD3<Float>(0, 0, 1): newScale.z = startScale.z * ratio
        default: break
        }

        var transform = scene.manager.getComponent(for: entity) as TransformComponent?
                     ?? TransformComponent()
        transform.scaleVec = newScale
        scene.manager.addComponent(component: transform, to: entity)
    }
    
    private static func generateCylinder(radialSegments: Int,
                                         cylinderHeight: Float,
                                         cylinderRadius: Float,
                                         coneHeight: Float,
                                         coneRadius: Float) -> [GizmoVertex] {
        var vertices: [GizmoVertex] = []
        let defaultColor = SIMD3<Float>(1, 1, 1)
        
        for i in 0..<radialSegments {
            let angle1 = (Float(i) / Float(radialSegments)) * 2.0 * .pi
            let angle2 = (Float(i + 1) / Float(radialSegments)) * 2.0 * .pi
            
            let cos1 = cos(angle1)
            let sin1 = sin(angle1)
            let cos2 = cos(angle2)
            let sin2 = sin(angle2)
            
            // --- 1. СТРОИМ СЕГМЕНТ ЦИЛИНДРА (Древко) ---
            let cx1 = cos1 * cylinderRadius
            let cz1 = sin1 * cylinderRadius
            let cx2 = cos2 * cylinderRadius
            let cz2 = sin2 * cylinderRadius
            
            // Первый треугольник боковины цилиндра
            vertices.append(GizmoVertex(position: [cx1, 0, cz1],              color: defaultColor))
            vertices.append(GizmoVertex(position: [cx1, cylinderHeight, cz1], color: defaultColor))
            vertices.append(GizmoVertex(position: [cx2, 0, cz2],              color: defaultColor))
            
            // Второй треугольник боковины цилиндра
            vertices.append(GizmoVertex(position: [cx2, 0, cz2],              color: defaultColor))
            vertices.append(GizmoVertex(position: [cx1, cylinderHeight, cz1], color: defaultColor))
            vertices.append(GizmoVertex(position: [cx2, cylinderHeight, cz2], color: defaultColor))
            
            // --- 2. СТРОИМ СЕГМЕНТ КОНУСА (Наконечник) ---
            // Конус начинается на высоте цилиндра и идет вверх до вершины
            let kx1 = cos1 * coneRadius
            let kz1 = sin1 * coneRadius
            let kx2 = cos2 * coneRadius
            let kz2 = sin2 * coneRadius
            
            let coneBaseY = cylinderHeight
            let coneTipY  = cylinderHeight + coneHeight
            
            // Треугольник конуса: две точки на основании, одна на вершине (0, tipY, 0)
            vertices.append(GizmoVertex(position: [kx1, coneBaseY, kz1], color: defaultColor))
            vertices.append(GizmoVertex(position: [kx2, coneBaseY, kz2], color: defaultColor))
            vertices.append(GizmoVertex(position: [0,   coneTipY,  0],   color: defaultColor))
        }
        return vertices
    }
    
    private static func generateRing(majorSegments: Int,
                                     minorSegments: Int,
                                     majorRadius: Float,
                                     minorRadius: Float) -> [GizmoVertex] {
        var vertices: [GizmoVertex] = []
        let color = SIMD3<Float>(1, 1, 1)
        let up = SIMD3<Float>(0, 1, 0)

        for i in 0..<majorSegments {
            let theta1 = Float(i)     / Float(majorSegments) * 2 * .pi
            let theta2 = Float(i + 1) / Float(majorSegments) * 2 * .pi

            let cosT1 = cos(theta1), sinT1 = sin(theta1)
            let cosT2 = cos(theta2), sinT2 = sin(theta2)

            // Центр трубки в двух соседних сечениях кольца (плоскость XZ)
            let c1 = SIMD3<Float>(cosT1 * majorRadius, 0, sinT1 * majorRadius)
            let c2 = SIMD3<Float>(cosT2 * majorRadius, 0, sinT2 * majorRadius)

            // Направление «наружу» от центра кольца (в плоскости XZ)
            let n1 = SIMD3<Float>(cosT1, 0, sinT1)
            let n2 = SIMD3<Float>(cosT2, 0, sinT2)

            for j in 0..<minorSegments {
                let phi1 = Float(j)     / Float(minorSegments) * 2 * .pi
                let phi2 = Float(j + 1) / Float(minorSegments) * 2 * .pi

                // Точки на поверхности тора:
                //   P = центр_трубки + (cos(phi)·наружу + sin(phi)·вверх) · minorRadius
                let p11 = c1 + (n1 * cos(phi1) + up * sin(phi1)) * minorRadius
                let p12 = c1 + (n1 * cos(phi2) + up * sin(phi2)) * minorRadius
                let p21 = c2 + (n2 * cos(phi1) + up * sin(phi1)) * minorRadius
                let p22 = c2 + (n2 * cos(phi2) + up * sin(phi2)) * minorRadius

                // Квад → два треугольника
                vertices.append(GizmoVertex(position: p11, color: color))
                vertices.append(GizmoVertex(position: p21, color: color))
                vertices.append(GizmoVertex(position: p12, color: color))

                vertices.append(GizmoVertex(position: p12, color: color))
                vertices.append(GizmoVertex(position: p21, color: color))
                vertices.append(GizmoVertex(position: p22, color: color))
            }
        }
        return vertices
    }
    
    private static func generateCylinderStem(radialSegments: Int,
                                              height: Float,
                                              radius: Float) -> [GizmoVertex] {
        var vertices: [GizmoVertex] = []
        let color = SIMD3<Float>(1, 1, 1)
        for i in 0..<radialSegments {
            let a1 = Float(i)     / Float(radialSegments) * 2 * .pi
            let a2 = Float(i + 1) / Float(radialSegments) * 2 * .pi
            let c1 = cos(a1), s1 = sin(a1)
            let c2 = cos(a2), s2 = sin(a2)

            let x1 = c1 * radius, z1 = s1 * radius
            let x2 = c2 * radius, z2 = s2 * radius

            vertices.append(GizmoVertex(position: [x1, 0,      z1], color: color))
            vertices.append(GizmoVertex(position: [x1, height, z1], color: color))
            vertices.append(GizmoVertex(position: [x2, 0,      z2], color: color))

            vertices.append(GizmoVertex(position: [x2, 0,      z2], color: color))
            vertices.append(GizmoVertex(position: [x1, height, z1], color: color))
            vertices.append(GizmoVertex(position: [x2, height, z2], color: color))
        }
        return vertices
    }

    private static func generateCube(size: Float) -> [GizmoVertex] {
        let h = size * 0.5
        let color = SIMD3<Float>(1, 1, 1)
        let c: [SIMD3<Float>] = [
            [-h, -h, -h], [ h, -h, -h], [ h,  h, -h], [-h,  h, -h],
            [-h, -h,  h], [ h, -h,  h], [ h,  h,  h], [-h,  h,  h],
        ]
        let tris: [(Int, Int, Int)] = [
            (0,2,1),(0,3,2),     // -Z
            (4,5,6),(4,6,7),     // +Z
            (0,1,5),(0,5,4),     // -Y
            (3,7,6),(3,6,2),     // +Y
            (0,4,7),(0,7,3),     // -X
            (1,2,6),(1,6,5),     // +X
        ]
        var out: [GizmoVertex] = []
        for (a, b, d) in tris {
            out.append(GizmoVertex(position: c[a], color: color))
            out.append(GizmoVertex(position: c[b], color: color))
            out.append(GizmoVertex(position: c[d], color: color))
        }
        return out
    }
    
    private func updateHover(origin: SIMD3<Float>,
                             worldLength: Float,
                             gizmoScale: Float,
                             mode: GizmoMode,
                             uniforms: Uniforms,
                             params: Params) {
        let cursor = InputController.shared.hoverLocation ?? InputController.shared.touchLocation
        guard let cursor else { hoveredAxis = nil; return }
        
        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard viewSize.width > 0,
              viewSize.height > 0,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor,
                                             viewSize: viewSize,
                                             uniforms: uniforms) else { hoveredAxis = nil; return }
        
        let threshold = GizmoHitTest.screenSpaceThreshold(origin: origin, uniforms: uniforms,
                                                          params: params, pixelTolerance: 6)
        
        switch mode {
        case .translate:
            hoveredAxis = pickTranslateAxis(
                ray: ray,
                origin: origin,
                worldLength: worldLength,
                gizmoScale: gizmoScale,
                threshold: threshold)
            
        case .rotate:
            hoveredAxis = pickRotationAxis(
                ray: ray,
                origin: origin,
                gizmoScale: gizmoScale,
                threshold: threshold)
            
        case .scale:
            hoveredAxis = pickScaleAxis(
                ray: ray,
                origin: origin,
                worldLength: worldLength,
                gizmoScale: gizmoScale,
                threshold: threshold)
        }
    }
    
    private func pickTranslateAxis(ray: Ray,
                                   origin: SIMD3<Float>,
                                   worldLength: Float,
                                   gizmoScale: Float,
                                   threshold: Float) -> GizmoAxis? {
        var best: (axis: GizmoAxis, dist: Float)?
        for axis in GizmoAxis.allCases {
            let segA = origin
            let segB = origin + axis.direction * worldLength
            guard let hit = GizmoHitTest.hitDistanceRayToSegment(ray: ray, segA: segA, segB: segB)
            else { continue }

            let u = hit.s / worldLength
            let radiusInWorld = shaftRadiusAt(u) * gizmoScale

            if hit.distance < radiusInWorld + threshold {
                if best == nil || hit.distance < best!.dist {
                    best = (axis, hit.distance)
                }
            }
        }
        return best?.axis
    }
    
    private func pickRotationAxis(ray: Ray,
                                  origin: SIMD3<Float>,
                                  gizmoScale: Float,
                                  threshold: Float) -> GizmoAxis? {
        // Радиусы — те же, что в generateRing, помноженные на gizmoScale.
        // majorRadius = 0.7, minorRadius = 0.03 — должны совпадать с init!
        let worldRadius     = 0.7  * gizmoScale
        let worldTubeRadius = 0.03 * gizmoScale

        var best: (axis: GizmoAxis, dist: Float)?
        for axis in GizmoAxis.allCases {
            guard let dist = GizmoHitTest.hitRing(ray: ray,
                                                  center: origin,
                                                  axis: axis,
                                                  worldRadius: worldRadius,
                                                  worldTubeRadius: worldTubeRadius,
                                                  worldTolerance: threshold)
            else { continue }

            if best == nil || dist < best!.dist {
                best = (axis, dist)
            }
        }
        return best?.axis
    }
    
    private func pickScaleAxis(ray: Ray, origin: SIMD3<Float>,
                                worldLength: Float, gizmoScale: Float,
                                threshold: Float) -> GizmoAxis? {
        let radiusInWorld: Float = 0.06 * gizmoScale    // чуть шире, чтобы кубик тоже цеплялся
        var best: (axis: GizmoAxis, dist: Float)?
        for axis in GizmoAxis.allCases {
            let segA = origin
            let segB = origin + axis.direction * worldLength
            guard let hit = GizmoHitTest.hitDistanceRayToSegment(ray: ray, segA: segA, segB: segB)
            else { continue }
            if hit.distance < radiusInWorld + threshold {
                if best == nil || hit.distance < best!.dist {
                    best = (axis, hit.distance)
                }
            }
        }
        return best?.axis
    }

    private func shaftRadiusAt(_ u: Float) -> Float {
        if u < Self.shaftFraction { return Self.cylinderRadius }
        let t = (u - Self.shaftFraction) / (1.0 - Self.shaftFraction)
        return Self.coneRadius * (1.0 - t)
    }
    
    private func updateDragState(origin: SIMD3<Float>, scene: SceneManager,
                                 uniforms: Uniforms, params: Params, mode: GizmoMode) {
        let isDown = InputController.shared.isMouseButtonDown
        let justPressed  =  isDown && !wasMouseDownLastFrame
        let justReleased = !isDown &&  wasMouseDownLastFrame
        
        if justPressed, let grabbed = hoveredAxis, let selected = scene.selectedEntity {
            activeAxis = grabbed
            
            switch mode {
            case .translate:
                beginDrag(axis: grabbed, origin: origin, entity: selected,
                          scene: scene, uniforms: uniforms, params: params)
            case .rotate:
                beginRotateDrag(axis: grabbed, origin: origin, entity: selected,
                                scene: scene, uniforms: uniforms, params: params)
            case .scale:
                beginScaleDrag(axis: grabbed, origin: origin, entity: selected,
                               scene: scene, uniforms: uniforms, params: params)
            }
            InputController.shared.gizmoCaptured = true
        }
        if justReleased {
            activeAxis = nil
            dragAxisWorldDir = nil
            dragPlaneOrigin  = nil
            dragPlaneNormal  = nil
            dragEntity       = nil
            dragStartWorldPivot = nil
            rotateStartVector = nil
            rotateStartQuat   = nil
            rotateAxisDir     = nil
            dragStartScaleVec = nil
            rotateAccumulated = 0
            rotatePrevAngle   = 0
            InputController.shared.gizmoCaptured = false
        }
        wasMouseDownLastFrame = isDown
    }
    
    private func beginDrag(axis: GizmoAxis,
                           origin: SIMD3<Float>,
                           entity: Entity,
                           scene: SceneManager,
                           uniforms: Uniforms,
                           params: Params) {
        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor,
                                              viewSize: viewSize,
                                              uniforms: uniforms)
        else { return }

        let axisDir = axis.direction
        let camPos = SIMD3<Float>(uniforms.viewMatrix.inverse.columns.3.x,
                                  uniforms.viewMatrix.inverse.columns.3.y,
                                  uniforms.viewMatrix.inverse.columns.3.z)
        let camToGizmo = origin - camPos
        let camPerp = camToGizmo - axisDir * simd_dot(axisDir, camToGizmo)
        let camPerpLen = simd_length(camPerp)
        guard camPerpLen > 1e-4 else { return }          // камера на оси — драг невозможен
        let planeNormalN = camPerp / camPerpLen

        print("plane denom =", simd_dot(planeNormalN, ray.direction))
        guard let hit0 = GizmoHitTest.rayPlaneIntersection(ray: ray,
                                                           planePoint: origin,
                                                           planeNormal: planeNormalN)
        else { return }

        dragAxisWorldDir    = axisDir
        dragPlaneOrigin     = origin
        dragPlaneNormal     = planeNormalN
        dragStartAxisParam  = simd_dot(hit0 - origin, axisDir)
        dragEntity          = entity

        let world = scene.manager.worldMatrix(for: entity)
        dragStartWorldPivot = SIMD3<Float>(world.columns.3.x,
                                           world.columns.3.y,
                                           world.columns.3.z)

        InputController.shared.gizmoCaptured = true
        print("beginDrag axis=\(axis) startS=\(dragStartAxisParam) planeN=\(planeNormalN)")
    }
    
    private func updateDrag(scene: SceneManager, uniforms: Uniforms, params: Params) {
        guard let axisDir = dragAxisWorldDir,
              let planeOrigin = dragPlaneOrigin,
              let planeNormal = dragPlaneNormal,
              let entity = dragEntity,
              let startWorldPivot = dragStartWorldPivot
        else { return }
        let viewSize = CGSize(width:  CGFloat(params.width)  / Renderer.scaleFactor,
                              height: CGFloat(params.height) / Renderer.scaleFactor)
        guard let cursor = InputController.shared.touchLocation ?? InputController.shared.hoverLocation,
              let ray = GizmoHitTest.makeRay(screenPoint: cursor,
                                              viewSize: viewSize,
                                              uniforms: uniforms),
              let hit = GizmoHitTest.rayPlaneIntersection(ray: ray,
                                                          planePoint: planeOrigin,
                                                          planeNormal: planeNormal)
        else { return }

        // Насколько уехала точка захвата вдоль оси
        let sNow = dot(hit - planeOrigin, axisDir)
        let delta = sNow - dragStartAxisParam

        let newWorldPivot = startWorldPivot + axisDir * delta

        print("sNow=\(sNow)  delta=\(delta)")
        applyWorldPivot(newWorldPivot, to: entity, scene: scene)
    }
    
    private func applyWorldPivot(_ worldPivot: SIMD3<Float>,
                                  to entity: Entity,
                                  scene: SceneManager) {
        var transform = scene.manager.getComponent(for: entity) as TransformComponent? ?? TransformComponent()

        if let parent = transform.parent {
            let parentWorld = scene.manager.worldMatrix(for: parent)
            let local4 = parentWorld.inverse * float4(worldPivot, 1)
            transform.position = SIMD3<Float>(local4.x, local4.y, local4.z)
        } else {
            transform.position = worldPivot
        }

        scene.manager.addComponent(component: transform, to: entity)
    }
}
