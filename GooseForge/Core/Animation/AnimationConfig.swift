//
//  AnimationConfig.swift
//  GooseForge
//
//  Created by Igorchela on 18.11.2026.
//

import Foundation

struct AnimationConfig {
    let keyword: String          // Ключевое слово для поиска клипа ("idle", "run", "jump", "punch")
    let blendDuration: Float     // Время плавного перехода (crossfade)
    let isLooping: Bool          // Зациклена ли анимация
    let useRootMotion: Bool      // Двигает ли анимация персонажа
    let canRotateInAction: Bool  // Можно ли слегка подруливать во время действия
}
