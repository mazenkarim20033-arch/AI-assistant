import CoreVideo
import SwiftUI

/// A detection that keeps the same identity from frame to frame, so boxes glide instead of flicker.
struct TrackedBox: Identifiable {
    let id: Int
    var rect: CGRect   // normalized, origin top-left
    var label: String
    var confidence: Float
    var missed = 0
}

/// Matches each new detection to the previous box with the same label and enough overlap,
/// blends their positions, and keeps a box for two extra frames if it briefly disappears.
struct BoxTracker {
    private var boxes: [TrackedBox] = []
    private var nextID = 0

    mutating func update(_ detections: [ObjectDetector.Detection]) -> [TrackedBox] {
        var unmatched = Array(boxes.indices)
        var result: [TrackedBox] = []

        for detection in detections {
            var best: (index: Int, overlap: CGFloat)?
            for index in unmatched where boxes[index].label == detection.label {
                let overlap = Self.intersectionOverUnion(boxes[index].rect, detection.rect)
                if overlap > 0.3, overlap > (best?.overlap ?? 0) {
                    best = (index, overlap)
                }
            }
            if let match = best {
                unmatched.removeAll { $0 == match.index }
                var box = boxes[match.index]
                box.rect = Self.blend(box.rect, detection.rect, 0.5)
                box.confidence = detection.confidence
                box.missed = 0
                result.append(box)
            } else {
                result.append(TrackedBox(id: nextID, rect: detection.rect, label: detection.label, confidence: detection.confidence))
                nextID += 1
            }
        }

        for index in unmatched {
            var box = boxes[index]
            box.missed += 1
            if box.missed <= 2 { result.append(box) }
        }
        boxes = result
        return result
    }

    private static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let overlap = intersection.width * intersection.height
        let union = a.width * a.height + b.width * b.height - overlap
        return union > 0 ? overlap / union : 0
    }

    private static func blend(_ a: CGRect, _ b: CGRect, _ amount: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * amount,
            y: a.minY + (b.minY - a.minY) * amount,
            width: a.width + (b.width - a.width) * amount,
            height: a.height + (b.height - a.height) * amount
        )
    }
}

/// Runs the object detector on the camera's live frames, at most about 8 times a second,
/// and publishes the tracked boxes. This is detection on selected frames, not continuous understanding.
final class LiveDetectionModel: ObservableObject {
    @Published private(set) var boxes: [TrackedBox] = []
    @Published private(set) var imageSize: CGSize = .zero

    private let detector = ObjectDetector.shared
    private var tracker = BoxTracker()
    private let lock = NSLock()
    private var busy = false
    private var lastRun = Date.distantPast

    var isAvailable: Bool { detector.isAvailable }

    /// Called on the camera's frame queue for every frame.
    func handle(_ buffer: CVPixelBuffer) {
        guard detector.isAvailable else { return }
        lock.lock()
        let now = Date()
        if busy || now.timeIntervalSince(lastRun) < 0.12 {
            lock.unlock()
            return
        }
        busy = true
        lastRun = now
        lock.unlock()

        let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        let detections = (try? detector.detect(pixelBuffer: buffer)) ?? []
        let tracked = tracker.update(detections)   // only touched here: one frame at a time
        DispatchQueue.main.async {
            self.boxes = tracked
            self.imageSize = size
        }

        lock.lock()
        busy = false
        lock.unlock()
    }

    func reset() {
        DispatchQueue.main.async { self.boxes = [] }
    }
}

/// Draws the boxes over the camera preview. The preview fills the screen (aspect fill), so the
/// box coordinates are scaled and offset the same way.
struct DetectionOverlay: View {
    let boxes: [TrackedBox]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            if imageSize.width > 0, imageSize.height > 0 {
                let scale = max(proxy.size.width / imageSize.width, proxy.size.height / imageSize.height)
                let offsetX = (proxy.size.width - imageSize.width * scale) / 2
                let offsetY = (proxy.size.height - imageSize.height * scale) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(boxes) { box in
                        let frame = CGRect(
                            x: box.rect.minX * imageSize.width * scale + offsetX,
                            y: box.rect.minY * imageSize.height * scale + offsetY,
                            width: box.rect.width * imageSize.width * scale,
                            height: box.rect.height * imageSize.height * scale
                        )
                        BoxView(label: box.label, confidence: box.confidence)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .opacity(box.missed == 0 ? 1 : 0.5)
                    }
                }
                .animation(.linear(duration: 0.12), value: boxes.map(\.rect))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BoxView: View {
    let label: String
    let confidence: Float

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.cyan, lineWidth: 2)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 6)
            Text("\(label) \(Int((confidence * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.cyan, in: Capsule())
                .offset(x: 4, y: 4)
        }
    }
}
