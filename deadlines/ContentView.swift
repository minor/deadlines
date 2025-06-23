//
//  ContentView.swift
//  deadlines
//
//  Created by saurish on 6/13/25.
//

import SwiftUI
import AppKit
import Combine

// Data model for a deadline
struct Deadline: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let deadlineDate = calendar.startOfDay(for: date)
        // Positive for future dates, 0 for today, negative for past dates.
        return calendar.dateComponents([.day], from: today, to: deadlineDate).day ?? 0
    }
}

// Individual deadline row with swipe-to-delete
struct DeadlineRowView: View {
    let deadline: Deadline
    @Binding var editingDeadlineId: UUID?
    @Binding var editingText: String
    let onDelete: () -> Void
    let onUpdate: (String) -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showingDeleteButton = false
    
    var body: some View {
        ZStack {
            // Delete button background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    ZStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 60)
                            .frame(maxHeight: .infinity)
                        
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(min(1, abs(offset / 60.0)))
            }
            
            // Main content with scroll tracking
            ZStack {
                // Content
                HStack {
                    if editingDeadlineId == deadline.id {
                        TextField("Deadline name", text: $editingText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .onSubmit {
                                onUpdate(editingText)
                                editingDeadlineId = nil
                                editingText = ""
                            }
                            .onAppear {
                                editingText = deadline.name
                            }
                    } else {
                        Text(deadline.name)
                            .font(.system(size: 14))
                            .onTapGesture(count: 2) {
                                editingDeadlineId = deadline.id
                                editingText = deadline.name
                            }
                    }
                    
                    Spacer()
                    
                    Text(daysUntilText(for: deadline.daysUntil))
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.clear)
                
                // Scroll tracking view on top
                ScrollTrackingView(
                    onHorizontalScroll: { deltaX in
                        // Invert scroll direction so a right-to-left swipe reveals the action.
                        let newOffset = offset - deltaX
                        let clampedOffset = min(0, max(-60, newOffset))
                        
                        // Only update if there's a change to avoid unnecessary re-renders
                        if clampedOffset != offset {
                            offset = clampedOffset
                        }
                    },
                    onScrollEnded: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if offset < -30 {
                                offset = -60
                                showingDeleteButton = true
                            } else {
                                offset = 0
                                showingDeleteButton = false
                            }
                        }
                    }
                )
            }
            .offset(x: offset)
            .onTapGesture {
                // Tap to close delete button if it's showing
                if showingDeleteButton {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = 0
                        showingDeleteButton = false
                    }
                }
            }
        }
        .clipped()
    }
}

// Menu bar content view
struct MenuBarView: View {
    @StateObject private var deadlineManager = DeadlineManager()
    @State private var isAddingDeadline = false
    @State private var newDeadlineName = ""
    @State private var newDeadlineDate = Date()
    @State private var showDatePicker = false
    @State private var editingDeadlineId: UUID? = nil
    @State private var editingText = ""
    @State private var monthText = ""
    @State private var dayText = ""
    @FocusState private var isEditingMonth: Bool
    @FocusState private var isEditingDay: Bool
    @FocusState private var isEditingDeadlineName: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Deadlines")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                Spacer()
            }
            
            // Add deadline row (when adding)
            if isAddingDeadline {
                HStack {
                    TextField("Deadline Name...", text: $newDeadlineName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .focused($isEditingDeadlineName)
                        .onSubmit {
                            if !newDeadlineName.isEmpty {
                                showDatePicker = true
                                DispatchQueue.main.async {
                                    isEditingMonth = true
                                }
                            }
                        }
                        .onKeyPress(.tab) {
                            if !newDeadlineName.isEmpty {
                                showDatePicker = true
                                DispatchQueue.main.async {
                                    isEditingMonth = true
                                }
                            }
                            return .handled
                        }
                        .onAppear {
                            // Auto-focus when the text field appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isEditingDeadlineName = true
                            }
                        }
                    
                    Spacer()
                    
                    if showDatePicker {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // Month input
                            ZStack {
                                TextField("MM", text: $monthText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .focused($isEditingMonth)
                                    .onChange(of: monthText) {
                                        // Limit to 2 digits and auto-advance
                                        let newValue = String(monthText.prefix(2))
                                        if newValue != monthText {
                                            monthText = newValue
                                        }
                                        if monthText.count == 2, let month = Int(monthText), month >= 1 && month <= 12 {
                                            DispatchQueue.main.async {
                                                isEditingMonth = false
                                                isEditingDay = true
                                            }
                                        }
                                    }
                                    .onSubmit {
                                        if !dayText.isEmpty && !monthText.isEmpty {
                                            createDeadlineFromInput()
                                        } else if !monthText.isEmpty {
                                            isEditingDay = true
                                        }
                                    }
                            }
                            .background(Color.clear)
                            .frame(width: 24)
                            
                            Text("/")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            
                            // Day input
                            ZStack {
                                TextField("DD", text: $dayText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .focused($isEditingDay)
                                    .onChange(of: dayText) {
                                        // Limit to 2 digits only
                                        dayText = String(dayText.prefix(2))
                                    }
                                    .onSubmit {
                                        if !dayText.isEmpty && !monthText.isEmpty {
                                            createDeadlineFromInput()
                                        }
                                    }
                                    .onKeyPress(.tab) {
                                        if !dayText.isEmpty && !monthText.isEmpty {
                                            createDeadlineFromInput()
                                        }
                                        return .handled
                                    }
                            }
                            .background(Color.clear)
                            .frame(width: 24)
                        }
                        .frame(width: 60, alignment: .trailing)
                    } else {
                        Text("MM / DD")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .onTapGesture {
                                if !newDeadlineName.isEmpty {
                                    showDatePicker = true
                                    isEditingMonth = true
                                }
                            }
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            
            // Existing deadlines
            ForEach(deadlineManager.sortedDeadlines) { deadline in
                DeadlineRowView(
                    deadline: deadline,
                    editingDeadlineId: $editingDeadlineId,
                    editingText: $editingText,
                    onDelete: { deadlineManager.removeDeadline(deadline) },
                    onUpdate: { newName in deadlineManager.updateDeadlineName(id: deadline.id, newName: newName) }
                )
            }
            
            // Separator
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Add deadline button
            Button(action: {
                if isAddingDeadline {
                    resetAddDeadlineState()
                } else {
                    isAddingDeadline = true
                }
            }) {
                HStack {
                    Text("Add Deadline...")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Separator
            Divider()
                .padding(.horizontal, 16)
            
            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit Deadlines")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("⌘Q")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 280)
        .background(VisualEffectView())
        // When the popover closes, discard any unfinished add-deadline draft so it doesn't persist.
        .onDisappear {
            if isAddingDeadline {
                resetAddDeadlineState()
            }
        }
        // NSPopover.willCloseNotification is sent whenever this menu-bar popover is dismissed.
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willCloseNotification)) { _ in
            if isAddingDeadline {
                resetAddDeadlineState()
            }
        }
    }
    
    private func resetAddDeadlineState() {
        isAddingDeadline = false
        showDatePicker = false
        newDeadlineName = ""
        newDeadlineDate = Date()
        monthText = ""
        dayText = ""
        isEditingMonth = false
        isEditingDay = false
        isEditingDeadlineName = false
    }
    
    private func createDeadlineFromInput() {
        guard let day = Int(dayText), let month = Int(monthText),
              day >= 1 && day <= 31, month >= 1 && month <= 12,
              !newDeadlineName.isEmpty else { return }
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var dateComponents = DateComponents()
        dateComponents.year = currentYear
        dateComponents.month = month
        dateComponents.day = day
        
        if let date = calendar.date(from: dateComponents) {
            deadlineManager.addDeadline(name: newDeadlineName, date: date)
            resetAddDeadlineState()
        }
    }
}

// Deadline manager to handle data persistence
class DeadlineManager: ObservableObject {
    @Published var deadlines: [Deadline] = []
    
    private let userDefaults = UserDefaults.standard
    private let deadlinesKey = "SavedDeadlines"
    
    // Timer that fires at local midnight to refresh `daysUntil` calculations
    private var midnightTimer: Timer?
    
    init() {
        loadDeadlines()
        
        // Schedule the first midnight refresh
        scheduleMidnightTimer()
    }
    
    var sortedDeadlines: [Deadline] {
        deadlines.sorted { first, second in
            if first.daysUntil == second.daysUntil {
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
            return first.daysUntil < second.daysUntil
        }
    }
    
    func addDeadline(name: String, date: Date) {
        let deadline = Deadline(name: name, date: date)
        deadlines.append(deadline)
        saveDeadlines()
    }
    
    func removeDeadline(_ deadline: Deadline) {
        deadlines.removeAll { $0.id == deadline.id }
        saveDeadlines()
    }
    
    func updateDeadlineName(id: UUID, newName: String) {
        if let index = deadlines.firstIndex(where: { $0.id == id }) {
            deadlines[index].name = newName
            saveDeadlines()
        }
    }
    
    private func saveDeadlines() {
        if let encoded = try? JSONEncoder().encode(deadlines) {
            userDefaults.set(encoded, forKey: deadlinesKey)
        }
    }
    
    // Remove deadlines that have been overdue for longer than `overdueDeletionThreshold` days.
    private func cleanupOverdueDeadlines() {
        let overdueDeletionThreshold = -7 // days (negative)
        let originalCount = deadlines.count
        deadlines.removeAll { $0.daysUntil < overdueDeletionThreshold }
        if deadlines.count != originalCount {
            saveDeadlines()
        }
    }
    
    private func loadDeadlines() {
        if let data = userDefaults.data(forKey: deadlinesKey),
           let decoded = try? JSONDecoder().decode([Deadline].self, from: data) {
            deadlines = decoded
        } else {
            // Add sample data for testing
            deadlines = [
                Deadline(name: "Project Alpha", date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()),
                Deadline(name: "Submit Report", date: Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()),
                Deadline(name: "Conference", date: Calendar.current.date(byAdding: .day, value: 24, to: Date()) ?? Date())
            ]
        }
        
        // Initial cleanup in case stored data contains very old deadlines.
        cleanupOverdueDeadlines()
    }
    
    // MARK: - Midnight refresh
    
    /// Schedules a one-shot timer that fires at the next local midnight.
    private func scheduleMidnightTimer() {
        midnightTimer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        
        // Find the next occurrence of 00:00:00 in the current calendar/time zone
        if let nextMidnight = calendar.nextDate(after: now,
                                                matching: DateComponents(hour: 0, minute: 0, second: 0),
                                                matchingPolicy: .strict,
                                                direction: .forward) {
            midnightTimer = Timer(fireAt: nextMidnight,
                                   interval: 0,
                                   target: self,
                                   selector: #selector(handleMidnight),
                                   userInfo: nil,
                                   repeats: false)
            if let midnightTimer {
                RunLoop.main.add(midnightTimer, forMode: .common)
            }
        }
    }
    
    /// Called when the day changes; notifies observers and reschedules the timer.
    @objc private func handleMidnight() {
        // Remove any deadlines that are past the overdue threshold before notifying views.
        cleanupOverdueDeadlines()
        
        // Trigger view updates so `daysUntil` is recalculated during the next render.
        objectWillChange.send()
        
        // Prepare for the following day.
        scheduleMidnightTimer()
    }
}

// Legacy ContentView for compatibility
struct ContentView: View {
    var body: some View {
        MenuBarView()
    }
}

// Scroll tracking view for trackpad gestures
struct ScrollTrackingView: NSViewRepresentable {
    let onHorizontalScroll: (CGFloat) -> Void
    let onScrollEnded: () -> Void
    
    func makeNSView(context: Context) -> ScrollTrackingNSView {
        let view = ScrollTrackingNSView()
        view.onHorizontalScroll = onHorizontalScroll
        view.onScrollEnded = onScrollEnded
        return view
    }
    
    func updateNSView(_ nsView: ScrollTrackingNSView, context: Context) {
        nsView.onHorizontalScroll = onHorizontalScroll
        nsView.onScrollEnded = onScrollEnded
    }
}

class ScrollTrackingNSView: NSView {
    var onHorizontalScroll: ((CGFloat) -> Void)?
    var onScrollEnded: (() -> Void)?
    private var isHorizontallyScrolling = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupScrollTracking()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScrollTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollTracking()
    }
    
    private func setupScrollTracking() {
        // Accept first responder to receive scroll events
        wantsLayer = true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began {
            isHorizontallyScrolling = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }
        
        if isHorizontallyScrolling {
            onHorizontalScroll?(event.scrollingDeltaX)
            
            if event.phase == .ended || event.phase == .cancelled || (event.momentumPhase == .ended) {
                onScrollEnded?()
                isHorizontallyScrolling = false
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Become first responder when mouse enters
        window?.makeFirstResponder(self)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }
        
        // Add new tracking area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
}

// Visual Effect View for native macOS translucent background
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// Helper function to format days until text
func daysUntilText(for days: Int) -> String {
    if days < 0 {
        return "Overdue!"
    }
    switch days {
    case 0:
        return "Today!"
    case 1:
        return "1 day"
    default:
        return "\(days) days"
    }
}

#Preview {
    MenuBarView()
}
