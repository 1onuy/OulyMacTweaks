import SwiftUI
import SpriteKit

private final class SnowScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        let emitter = makeEmitter()
        emitter.position = CGPoint(x: frame.midX, y: frame.maxY + 20)
        emitter.particlePositionRange = CGVector(dx: frame.width * 1.2, dy: 0)
        addChild(emitter)
    }

    private func makeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture    = circleTexture()
        e.particleBirthRate  = 8
        e.particleLifetime   = 12
        e.particleLifetimeRange = 6
        e.particleSpeed      = 50
        e.particleSpeedRange = 25
        e.emissionAngle      = -.pi / 2
        e.emissionAngleRange = .pi / 10
        e.particleScale      = 0.012
        e.particleScaleRange = 0.008
        e.particleAlpha      = 0.35
        e.particleAlphaRange = 0.15
        e.particleColor      = .white
        e.xAcceleration      = 8
        return e
    }

    private func circleTexture() -> SKTexture {
        let size = CGSize(width: 12, height: 12)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return SKTexture(image: img)
    }
}

struct SnowBackgroundView: View {
    private let scene: SnowScene = {
        let s = SnowScene()
        s.scaleMode = .resizeFill
        s.preferredFramesPerSecond = 30
        return s
    }()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didResignActiveNotification)
            ) { _ in scene.isPaused = true }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didBecomeActiveNotification)
            ) { _ in scene.isPaused = false }
    }
}
