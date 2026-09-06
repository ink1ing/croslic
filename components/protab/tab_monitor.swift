import Cocoa
import Carbon

class TabKeyMonitor {
    private var eventTap: CFMachPort?
    private var isWaitingForLetter = false
    private var isTabHeld = false
    private var tabPressTime: DispatchTime?

    // Get script directory (executable location)
    private var scriptDir: String {
        if let path = Bundle.main.executablePath {
            return (path as NSString).deletingLastPathComponent
        }
        return FileManager.default.currentDirectoryPath
    }

    func start() {
        // Start listener without requesting Accessibility control permission.
        setupEventTap()
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<TabKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap = eventTap else {
            print("Failed to create global event listener")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Ignore modifier key combinations
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskShift) {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp && keyCode == 48 {
            isTabHeld = false
            isWaitingForLetter = false
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            // Tab key pressed (keyCode 48)
            if keyCode == 48 {
                isTabHeld = true
                isWaitingForLetter = true
                tabPressTime = DispatchTime.now()

                // Set timeout, cancel waiting after 500ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isWaitingForLetter = false
                }
                return Unmanaged.passUnretained(event)
            }

            // If waiting for letter key
            if isWaitingForLetter && isTabHeld {
                if let tabTime = tabPressTime, DispatchTime.now() < tabTime + .milliseconds(500) {
                    let letter = keyCodeToLetter(keyCode)
                    if !letter.isEmpty {
                        executeCommand(for: letter)
                        isWaitingForLetter = false
                        return Unmanaged.passUnretained(event)
                    }
                }
                isWaitingForLetter = false
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func executeCommand(for key: String) {
        let scriptPath: String

        switch key.lowercased() {
        // Terminal & IDE
        case "t":
            scriptPath = "\(scriptDir)/shortcuts/new_terminal.sh"
        case "l":
            scriptPath = "\(scriptDir)/shortcuts/new_claude_code.sh"
        case "o":
            scriptPath = "\(scriptDir)/shortcuts/new_codex.sh"
        case "u":
            scriptPath = "\(scriptDir)/shortcuts/update_claude_code.sh"
        case "p":
            scriptPath = "\(scriptDir)/shortcuts/update_codex.sh"

        // Edit files
        case "m":
            scriptPath = "\(scriptDir)/shortcuts/edit_claude_md.sh"
        case "d":
            scriptPath = "\(scriptDir)/shortcuts/edit_agents_md.sh"
        case "j":
            scriptPath = "\(scriptDir)/shortcuts/edit_settings_json.sh"

        // Browser
        case "b":
            scriptPath = "\(scriptDir)/shortcuts/new_private_tab.sh"

        // System
        case "r":
            scriptPath = "\(scriptDir)/shortcuts/clean_ram.sh"
        case "n":
            scriptPath = "\(scriptDir)/shortcuts/network_test.sh"
        case "x":
            scriptPath = "\(scriptDir)/shortcuts/toggle_vpn.sh"
        case "q":
            scriptPath = "\(scriptDir)/shortcuts/open_force_quit.sh"

        // Media
        case "s":
            scriptPath = "\(scriptDir)/shortcuts/screenshot.sh"
        case "v":
            scriptPath = "\(scriptDir)/shortcuts/record.sh"

        // Tools
        case "c":
            scriptPath = "\(scriptDir)/shortcuts/close_idle_terminals.sh"
        case "h":
            scriptPath = "\(scriptDir)/shortcuts/custom_h.sh"
        case "a":
            scriptPath = "\(scriptDir)/shortcuts/custom_a.sh"

        default:
            // Try custom script
            let customPath = "\(scriptDir)/shortcuts/custom_\(key.lowercased()).sh"
            if FileManager.default.fileExists(atPath: customPath) {
                scriptPath = customPath
            } else {
                return
            }
        }

        DispatchQueue.global().async {
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [scriptPath]
            // Suppress all output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }
}

// Key code to letter mapping
func keyCodeToLetter(_ keyCode: Int64) -> String {
    switch keyCode {
    case 0: return "a"
    case 11: return "b"
    case 8: return "c"
    case 2: return "d"
    case 14: return "e"
    case 3: return "f"
    case 5: return "g"
    case 4: return "h"
    case 34: return "i"
    case 38: return "j"
    case 40: return "k"
    case 37: return "l"
    case 46: return "m"
    case 45: return "n"
    case 31: return "o"
    case 35: return "p"
    case 12: return "q"
    case 15: return "r"
    case 1: return "s"
    case 17: return "t"
    case 32: return "u"
    case 9: return "v"
    case 13: return "w"
    case 7: return "x"
    case 16: return "y"
    case 6: return "z"
    default: return ""
    }
}

// Start monitor
let monitor = TabKeyMonitor()
monitor.start()

// Keep running
CFRunLoopRun()
