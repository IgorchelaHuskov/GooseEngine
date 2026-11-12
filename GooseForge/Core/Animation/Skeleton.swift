//
//  Skeleton.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import MetalKit

struct Skeleton {
    let parentIndices: [Int?]
    let jointPaths: [String]
    let bindTransforms: [float4x4]
    let restTransforms: [float4x4]
    var currentPose: [float4x4] = []
    
    init?(mdlSkeleton: MDLSkeleton?) {
        guard let mdlSkeleton, !mdlSkeleton.jointPaths.isEmpty else { return nil }
        jointPaths = mdlSkeleton.jointPaths
        parentIndices = Skeleton.getParentIndices(jointPaths: jointPaths)
        bindTransforms = mdlSkeleton.jointBindTransforms.float4x4Array
        restTransforms = mdlSkeleton.jointRestTransforms.float4x4Array
    }
    
    static func getParentIndices(jointPaths: [String]) -> [Int?] {
        var parentIndices = [Int?](repeating: nil, count: jointPaths.count)
        for (jointIndex, jointPath) in jointPaths.enumerated() {
            let url = URL(fileURLWithPath: jointPath)
            let parentPath = url.deletingLastPathComponent().relativePath
            parentIndices[jointIndex] = jointPaths.firstIndex { $0 == parentPath }
        }
        return parentIndices
    }
}
