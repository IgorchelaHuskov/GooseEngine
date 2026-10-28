//
//  InputController.swift
//  ECSRenderer
//
//  Created by Igorchela on 11.08.2026.
//

internal import GameController

@MainActor
class InputController {
    private var _pickRequest: CGPoint?
    
    struct Point {
        var x: Float
        var y: Float
        static let zero = Point(x: 0, y: 0)
    }
    
    var timer: Timer?
    var timerCount = 0
    var hoverLocation: CGPoint?
    var leftMouseDown = false
    var isMouseButtonDown: Bool = false
    var gizmoCaptured: Bool = false
    var duplicateRequested: Bool = false
    var deleteRequested: Bool = false
    var mouseDelta = Point.zero
    var mouseScroll = Point.zero
    var touchLocation: CGPoint?
    var touchDelta: CGSize? {
        didSet {
            touchDelta?.height *= -1
            if let delta = touchDelta {
                mouseDelta = Point(x: Float(delta.width), y: Float(delta.height))
            }
            leftMouseDown = touchDelta != nil
        }
    }
    
    static let shared = InputController()
    var keysPressed: Set<GCKeyCode> = []
    
    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: nil) { notification in
                let keyboard = notification.object as? GCKeyboard
                keyboard?.keyboardInput?.keyChangedHandler
                = { _, _, keyCode, pressed in
                    Task { @MainActor in
                        if pressed {
                            self.keysPressed.insert(keyCode)
                        } else {
                            self.keysPressed.remove(keyCode)
                        }
                    }
                }
            }
#if os(macOS)
NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .keyDown]) { event in
    // Если фокус находится в текстовом поле (NSTextView), не перехватываем клавиши
    if let responder = NSApp.keyWindow?.firstResponder,
       responder is NSTextView {
        return event
    }
    
    if event.type == .keyDown,
           event.modifierFlags.contains(.command),
       event.charactersIgnoringModifiers == "d" {
        Task { @MainActor in
            self.duplicateRequested = true
        }
        return nil // Съедаем событие, чтобы macOS не пикнула
    }
    
    if event.type == .keyDown,
       event.keyCode == 51 || event.keyCode == 117 { // 51 = Backspace, 117 = Delete (Forward Delete)
        Task { @MainActor in
            self.deleteRequested = true
        }
        return nil // Съедаем событие
    }
    
    return nil
}
#endif
        center.addObserver(
            forName: .GCMouseDidConnect,
            object: nil,
            queue: nil) { notification in
                let mouse = notification.object as? GCMouse
                mouse?.mouseInput?.leftButton.pressedChangedHandler = { _, _, pressed in
                    // slight delay to ensure that this is a drag
                    if pressed {
                        Task { @MainActor in
                            self.setTimer()
                        }
                    } else {
                        Task { @MainActor in
                            self.timer?.invalidate()
                            self.leftMouseDown = false
                        }
                    }
                }
                mouse?.mouseInput?.mouseMovedHandler = { _, deltaX, deltaY in
                    Task { @MainActor in
                        self.mouseDelta = Point(x: deltaX, y: deltaY)
                    }
                }
                mouse?.mouseInput?.scroll.valueChangedHandler = { _, xValue, yValue in
                    Task { @MainActor in
                        self.mouseScroll.x = xValue
                        self.mouseScroll.y = yValue
                    }
                }
            }
    }
    
    // MARK: - Set timer to ensure that the mouse down is a drag
    
    func setTimer() {
        timerCount = 0
        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(setMouseDown),
            userInfo: nil, repeats: true)
    }
    
    @objc func setMouseDown() {
        timerCount += 1
        if timerCount > 5 {
            timer?.invalidate()
            self.leftMouseDown = true
        }
    }
    
    func consumePickRequest() -> CGPoint? {
        defer { _pickRequest = nil }
        return _pickRequest
    }
    
    func requestPick(at point: CGPoint) {
        print("🖱 pick requested at \(point)")
        _pickRequest = point
    }
    
    func consumeDuplicateRequest() -> Bool {
        defer { duplicateRequested = false }
        return duplicateRequested
    }
    
    func consumeDeleteRequest() -> Bool {
        defer { deleteRequested = false }
        return deleteRequested
    }
}
