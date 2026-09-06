import Foundation

/// Deterministic per-ray and flare math for the sunburst drawn around the
/// playing country — pure functions in Core so the twinkle/flash behavior is
/// unit-testable independently of Canvas rendering.
public enum SparkleMath {
    /// Deterministic pseudo-random value in [0, 1) for a ray index (a
    /// fract-sine hash: stable across runs, so ray N always twinkles the
    /// same way at the same phase).
    public static func hash(_ index: Int) -> Double {
        let value = sin(Double(index) * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    /// Per-ray twinkle opacity in [0.3, 1]: a sine whose phase offset comes
    /// from the ray's hash, so neighboring rays sparkle out of sync. The
    /// frequency multiplier is an integer so the twinkle is 2π-periodic in
    /// `phase` (two full twinkles per ray-rotation cycle).
    public static func twinkleOpacity(index: Int, phase: Double) -> Double {
        let raw = 0.65 + 0.35 * sin(phase * 2.0 + hash(index) * 2 * .pi)
        return min(1, max(0.3, raw))
    }

    /// Sharp periodic flare envelope in [0, 1]: mostly near zero, spiking
    /// briefly once per 2π of phase — the "flash" the sunburst pulses with.
    public static func flareEnvelope(phase: Double) -> Double {
        let sine = sin(phase)
        guard sine > 0 else { return 0 }
        return pow(sine, 8)
    }
}
