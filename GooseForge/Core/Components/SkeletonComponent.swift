//
//  SkeletonComponent.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import Foundation

struct SkeletonComponent: Component {
    let parentIndices: [Int?]
    let jointPaths: [String]
    let bindTransforms: [float4x4]
    let restTransforms: [float4x4]
    var currentPose: [float4x4]
    
    func mapJoints(from jointPaths: [String]) -> [Int] {
        jointPaths.compactMap { jointPath in self.jointPaths.firstIndex(of: jointPath) }
    }
}
