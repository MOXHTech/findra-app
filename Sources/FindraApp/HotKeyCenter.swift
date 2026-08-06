import Carbon
import Foundation

@MainActor
final class HotKeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    func start(action: @escaping () -> Void) {
        self.action = action
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in center.action?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let signature = OSType(UInt32(ascii: "FND0"))
        let id = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

private extension UInt32 {
    init(ascii: String) {
        self = ascii.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
