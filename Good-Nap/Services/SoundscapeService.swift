//
//  SoundscapeService.swift
//  Good-Nap
//
//  Created by AI on 11/3/25.
//

import Foundation

class SoundscapeService: ObservableObject {
    static let shared = SoundscapeService()
    
    private init() {}
    
    func generatePlan(napDuration: TimeInterval, biometrics: SleepBiometrics) -> SoundscapePlan {
        let ambientProfile = AmbientProfile(
            name: "Gentle Morning",
            description: "Soft nature sounds with gradual volume increase",
            dynamicElements: ["birds", "water", "wind"]
        )
        
        let segments = [
            SoundscapeSegment(
                label: "Pre-wake",
                soundPalette: "Soft nature",
                coachingNote: "Preparing your mind for gentle awakening",
                startOffset: max(napDuration - 480, 0),
                duration: 210,
                intensity: "Low"
            ),
            SoundscapeSegment(
                label: "Wake transition",
                soundPalette: "Melodic tones",
                coachingNote: "Gradually increasing awareness",
                startOffset: max(napDuration - 210, 0),
                duration: 150,
                intensity: "Medium"
            ),
            SoundscapeSegment(
                label: "Final rise",
                soundPalette: "Bright chimes",
                coachingNote: "Inviting gentle alertness",
                startOffset: max(napDuration - 90, 0),
                duration: 120,
                intensity: "High"
            )
        ]
        
        return SoundscapePlan(
            recommendationSummary: "Optimized for your current biometrics",
            wakeEaseRating: "Gentle",
            cortisolReductionScore: 85.0,
            ambientProfile: ambientProfile,
            segments: segments
        )
    }
}
