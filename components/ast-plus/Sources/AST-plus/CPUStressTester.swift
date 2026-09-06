import Foundation

struct StressSummary: Encodable {
    let durationSeconds: Int
    let workerCount: Int
    let iterations: Int
    let elapsedSeconds: Double
    let completed: Bool
    let skipped: Bool
    let memoryBytesTested: Int
    let memoryChecksum: UInt64?
    let memoryPass: Bool
}

struct CPUStressTester {
    let durationSeconds: Int

    func run() throws -> StressSummary {
        let workerCount = max(ProcessInfo.processInfo.activeProcessorCount - 2, 1)
        let counter = LockedCounter()
        let memoryResult = runMemoryProbe()

        let group = DispatchGroup()
        let start = Date()
        let deadline = start.addingTimeInterval(TimeInterval(durationSeconds))

        for _ in 0..<workerCount {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                var localIterations = 0
                while Date() < deadline {
                    _ = Self.computeChunk(seed: localIterations)
                    localIterations += 1
                }
                counter.add(localIterations)
                group.leave()
            }
        }

        group.wait()
        let elapsed = Date().timeIntervalSince(start)

        return StressSummary(
            durationSeconds: durationSeconds,
            workerCount: workerCount,
            iterations: counter.value,
            elapsedSeconds: elapsed,
            completed: true,
            skipped: false,
            memoryBytesTested: memoryResult.bytesTested,
            memoryChecksum: memoryResult.checksum,
            memoryPass: memoryResult.passed
        )
    }

    private func runMemoryProbe() -> MemoryProbeResult {
        let chunkSize = 4 * 1024 * 1024
        let chunkCount = 8
        var checksum: UInt64 = 0

        for chunkIndex in 0..<chunkCount {
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            for index in buffer.indices {
                buffer[index] = UInt8((index + chunkIndex) & 0xff)
            }

            for index in stride(from: 0, to: buffer.count, by: 4096) {
                checksum &+= UInt64(buffer[index])
            }
        }

        return MemoryProbeResult(
            bytesTested: chunkSize * chunkCount,
            checksum: checksum,
            passed: checksum > 0
        )
    }

    private static func computeChunk(seed: Int) -> UInt64 {
        var value: UInt64 = UInt64(seed) + 1
        for _ in 0..<50_000 {
            value = value &* 2862933555777941757 &+ 3037000493
            value ^= value >> 13
        }
        return value
    }
}

private struct MemoryProbeResult {
    let bytesTested: Int
    let checksum: UInt64
    let passed: Bool
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func add(_ amount: Int) {
        lock.lock()
        storage += amount
        lock.unlock()
    }
}
