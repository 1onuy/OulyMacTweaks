import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var gaugeView: MenuBarGaugeView?
    private var updateTimer: Timer?
    private weak var monitor: SystemMonitor?

    // Called from OulyMacTweaksApp after the monitor is ready
    func connect(monitor: SystemMonitor) {
        self.monitor = monitor
        updateTimer?.invalidate()
        updateGauge()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateGauge()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSSquareStatusItemLength)
        guard let button = statusItem?.button else { return }

        let gauge = MenuBarGaugeView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        button.addSubview(gauge)
        button.target = self
        button.action = #selector(handleClick)
        gaugeView = gauge
    }

    private func updateGauge() {
        guard let score = monitor?.performanceScore else { return }
        DispatchQueue.main.async { [weak self] in
            self?.gaugeView?.score = score
        }
    }

    @objc private func handleClick() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }
}
