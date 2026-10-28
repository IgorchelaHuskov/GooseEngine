//
//  GizmoHitTest.swift
//  GooseForge
//
//  Created by Igorchela on 22.10.2026.
//

import Foundation

enum GizmoHitTest {
    
    // построение луча из пикселя мыши
    static func makeRay(screenPoint: CGPoint, viewSize: CGSize, uniforms: Uniforms) -> Ray? {
        // 1. Пиксель → NDC [-1..1], Y инвертируем (UI и Metal смотрят по-разному)
        let x = Float((screenPoint.x / viewSize.width)  * 2.0 - 1.0)
        let y = Float(1.0 - (screenPoint.y / viewSize.height) * 2.0)

        // 2. Две точки на clip-плоскостях Metal (z=0 near, z=1 far)
        let nearClip = SIMD4<Float>(x, y, 0, 1)
        let farClip  = SIMD4<Float>(x, y, 1, 1)

        let invProj = uniforms.projectionMatrix.inverse
        let invView = uniforms.viewMatrix.inverse

        let nearV = invProj * nearClip
        let farV  = invProj * farClip
        guard nearV.w > 1e-6, farV.w > 1e-6 else { return nil }

        // 3. clip → view → world (не забываем поделить на w)
        let nearW4 = invView * (nearV / nearV.w)
        let farW4  = invView * (farV  / farV.w)

        let nearW = SIMD3<Float>(nearW4.x, nearW4.y, nearW4.z)
        let farW  = SIMD3<Float>(farW4.x,  farW4.y,  farW4.z)

        // 4. Направление = far − near (нормализуем)
        let dir = farW - nearW
        let len = simd_length(dir)
        guard len > 1e-6 else { return nil }
        return Ray(origin: nearW, direction: dir / len)
    }
    
    // расстояние от луча до отрезка
    static func hitDistanceRayToSegment(ray: Ray,
                                        segA: SIMD3<Float>,
                                        segB: SIMD3<Float>) -> (s: Float, distance: Float)? {
        let axisVec = segB - segA
        let axisLen = simd_length(axisVec)
        guard axisLen > 1e-6 else { return nil }
        let axisN = axisVec / axisLen

        // Ближайшая точка на бесконечной прямой оси
        let w0 = ray.origin - segA
        let b  = dot(axisN, ray.direction)
        let d  = dot(axisN, w0)
        let e  = dot(ray.direction, w0)
        

        //let denom = 1.0 - b * b        // a*c − b*b, где a=c=1 (векторы нормализованы)
        //var s: Float = (abs(denom) < 1e-6) ? 0 : (b * e - d) / denom
        //s = max(0, min(axisLen, s))    // зажимаем в отрезок
        
        let denom = 1.0 - b * b
        var s: Float = (abs(denom) < 1e-6) ? 0 : (d - b * e) / denom
        s = max(0, min(axisLen, s))

        let pointOnSegment = segA + axisN * s

        // Проекция этой точки на луч — там будет ближайшая точка луча
        let t = dot(pointOnSegment - ray.origin, ray.direction)
        if t < 0 { return nil }        // пересечение за камерой

        let pointOnRay = ray.origin + ray.direction * t
        return (s: s, distance: simd_distance(pointOnSegment, pointOnRay))
    }
    
    //  порог в screen-space (12 пикселей)
    static func screenSpaceThreshold(origin: SIMD3<Float>,
                                      uniforms: Uniforms,
                                      params: Params,
                                      pixelTolerance: Float) -> Float {
        let invView   = uniforms.viewMatrix.inverse
        let camPos    = SIMD3<Float>(invView.columns.3.x, invView.columns.3.y, invView.columns.3.z)
        let dist      = max(0.01, simd_distance(origin, camPos))

        // tan(fov/2) = 1 / P[1][1]  для стандартной perspective-матрицы Metal
        let fovHalfTan = 1.0 / uniforms.projectionMatrix[1][1]
        let worldHeight = 2 * dist * fovHalfTan
        let pixelsPerUnit = Float(params.height) / max(worldHeight, 1e-3)
        return pixelTolerance / max(pixelsPerUnit, 1e-3)
    }
    
    static func rayPlaneIntersection(ray: Ray,
                                    planePoint: SIMD3<Float>,
                                    planeNormal: SIMD3<Float>) -> SIMD3<Float>? {
        let denom = dot(planeNormal, ray.direction)
        guard abs(denom) > 1e-6 else { return nil }    // луч параллелен плоскости
        let t = dot(planeNormal, planePoint - ray.origin) / denom
        guard t > 0 else { return nil }                // пересечение за камерой
        return ray.origin + ray.direction * t
    }
    
    /// Возвращает минимальное расстояние от луча до «трубки» кольца,
    /// или nil, если ни один сегмент не дал попадания.
    static func hitRing(ray: Ray,
                        center: SIMD3<Float>,
                        axis: GizmoAxis,
                        worldRadius: Float,       // majorRadius * gizmoScale
                        worldTubeRadius: Float,   // minorRadius * gizmoScale
                        worldTolerance: Float,    // screen-space порог в мире
                        segments: Int = 48) -> Float? {
        let (u, v) = axis.ringBasis
        let threshold = worldTubeRadius + worldTolerance

        var bestDist: Float = .infinity
        for i in 0..<segments {
            let a1 = Float(i)     / Float(segments) * 2 * .pi
            let a2 = Float(i + 1) / Float(segments) * 2 * .pi

            let p1 = center + (u * cos(a1) + v * sin(a1)) * worldRadius
            let p2 = center + (u * cos(a2) + v * sin(a2)) * worldRadius

            guard let hit = hitDistanceRayToSegment(ray: ray, segA: p1, segB: p2)
            else { continue }

            if hit.distance < bestDist { bestDist = hit.distance }
        }
        return bestDist < threshold ? bestDist : nil
    }
}
