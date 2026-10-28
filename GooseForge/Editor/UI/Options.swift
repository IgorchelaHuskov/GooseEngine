//
//  Options.swift
//  GooseEngine
//
//  Created by Igorchela on 10.10.2026.
//

import Foundation
import Observation

@Observable
public class Options {
    public init() {}
    
    public var turbidity: Float = 0.36
    public var sunElevation: Float = 0.53
    public var upperAtmosphereScattering: Float = 0.12
    public var groundAlbedo: Float = 0.33
    public var shouldGenerateSkybox = true
    public var sunAzimuth: Float = 0.0
    public var gamma: Float = 0.50
    public var exposure: Float = -1.5
    public var contrast: Float = 0.0
    public var saturation: Float = 0.30
}

