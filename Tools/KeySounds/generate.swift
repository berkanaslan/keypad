// Synthesises the key sounds chosen in RFC-0003. Usage: swift Tools/KeySounds/generate.swift <output-directory>
// Each sound is written alone and as a demo (three single taps, then a fast run of six).
import Foundation

let rate = 48_000.0

struct Noise {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53) * 2 - 1
    }
}

typealias Partial = (freq: Double, amp: Double, decay: Double)

func modal(_ partials: [Partial], length: Double) -> [Double] {
    (0..<Int(length * rate)).map { i in
        let t = Double(i) / rate
        return partials.reduce(0) { $0 + $1.amp * exp(-t / $1.decay) * sin(2 * .pi * $1.freq * t) }
    }
}

func bandNoise(center: Double, q: Double, amp: Double, decay: Double, length: Double, seed: UInt64) -> [Double] {
    var noise = Noise(state: seed)
    let w0 = 2 * Double.pi * center / rate
    let alpha = sin(w0) / (2 * q)
    let (b0, b2, a0, a1, a2) = (alpha, -alpha, 1 + alpha, -2 * cos(w0), 1 - alpha)
    var (x1, x2, y1, y2) = (0.0, 0.0, 0.0, 0.0)
    return (0..<Int(length * rate)).map { i in
        let t = Double(i) / rate
        let x = noise.next()
        let y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        (x2, x1, y2, y1) = (x1, x, y1, y)
        return amp * exp(-t / decay) * y * 4
    }
}

func mix(_ parts: [Double]...) -> [Double] {
    let n = parts.map(\.count).max() ?? 0
    return (0..<n).map { i in parts.reduce(0) { $0 + (i < $1.count ? $1[i] : 0) } }
}

func shape(_ s: [Double], attackMs: Double, peakDB: Double) -> [Double] {
    let attack = Int(attackMs / 1000 * rate)
    let faded = s.enumerated().map { i, v in i < attack ? v * Double(i) / Double(attack) : v }
    let peak = faded.map(abs).max() ?? 1
    let gain = pow(10, peakDB / 20) / peak
    return faded.map { $0 * gain }
}

func demo(_ click: [Double]) -> [Double] {
    let starts = [0.2, 0.8, 1.4] + (0..<6).map { 2.2 + Double($0) * 0.15 }
    var out = [Double](repeating: 0, count: Int(3.4 * rate))
    for start in starts {
        let offset = Int(start * rate)
        for (i, v) in click.enumerated() where offset + i < out.count { out[offset + i] += v }
    }
    return out
}

func writeWAV(_ samples: [Double], to path: String) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let pcm = samples.map { Int16(max(-1, min(1, $0)) * Double(Int16.max)) }
    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + pcm.count * 2))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(UInt32(rate))
    append(UInt32(rate * 2))
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(UInt32(pcm.count * 2))
    for sample in pcm { append(sample) }
    try data.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments[1]
let candidates: [(String, [Double])] = [
    (
        "wood",
        shape(
            mix(
                modal([(1150, 1.0, 0.010), (2700, 0.5, 0.005), (4400, 0.25, 0.003)], length: 0.06),
                bandNoise(center: 3000, q: 1.0, amp: 0.3, decay: 0.0015, length: 0.01, seed: 1)
            ), attackMs: 0.2, peakDB: -14)
    ),
    (
        "soft",
        shape(
            mix(
                bandNoise(center: 2400, q: 1.2, amp: 1.0, decay: 0.004, length: 0.03, seed: 2),
                modal([(190, 0.6, 0.012), (1600, 0.3, 0.004)], length: 0.05)
            ), attackMs: 0.3, peakDB: -14)
    ),
    (
        "deep",
        shape(
            mix(
                modal([(650, 1.0, 0.014), (1500, 0.4, 0.007)], length: 0.07),
                bandNoise(center: 1800, q: 1.0, amp: 0.25, decay: 0.002, length: 0.01, seed: 3)
            ), attackMs: 0.3, peakDB: -13)
    ),
    (
        "crisp",
        shape(
            mix(
                modal([(3400, 1.0, 0.003), (6100, 0.4, 0.002)], length: 0.025),
                bandNoise(center: 5000, q: 1.0, amp: 0.3, decay: 0.001, length: 0.008, seed: 4)
            ), attackMs: 0.1, peakDB: -16)
    ),
]
for (name, click) in candidates {
    try writeWAV(click, to: "\(dir)/\(name).wav")
    try writeWAV(demo(click), to: "\(dir)/\(name)-demo.wav")
}
print("wrote \(candidates.count * 2) files")
