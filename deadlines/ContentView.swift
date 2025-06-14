//
//  ContentView.swift
//  deadlines
//
//  Created by saurish on 6/13/25.
//

import SwiftUI
import AppKit

// Data model for a deadline
struct Deadline: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let deadlineDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: deadlineDate).day ?? 0
        
        // If the date is in the past, assume they mean next year
        if days < 0 {
            // Calculate days until the same date next year
            let nextYear = calendar.date(byAdding: .year, value: 1, to: deadlineDate) ?? deadlineDate
            return calendar.dateComponents([.day], from: today, to: nextYear).day ?? 0
        }
        
        return days
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
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .opacity(showingDeleteButton ? 1 : 0)
                .allowsHitTesting(showingDeleteButton) // Only allow clicks when visible
            }
            
            // Main content with scroll tracking
            ZStack {
                // Scroll tracking background (only active when delete button is not showing)
                if !showingDeleteButton {
                    ScrollTrackingView(
                        onHorizontalScroll: { deltaX in
                            // Only allow left swipe (negative delta)
                            if deltaX < 0 {
                                let newOffset = max(offset + deltaX * 2, -60)
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = newOffset
                                    showingDeleteButton = newOffset < -30
                                }
                            } else if deltaX > 0 && offset < 0 {
                                // Allow swiping back to close
                                let newOffset = min(offset + deltaX * 2, 0)
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = newOffset
                                    showingDeleteButton = newOffset < -30
                                }
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
                                isEditingMonth = true
                            }
                        }
                        .onKeyPress(.tab) {
                            if !newDeadlineName.isEmpty {
                                showDatePicker = true
                                isEditingMonth = true
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
                        HStack(spacing: 2) {
                            // Month input
                            TextField("MM", text: $monthText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .frame(width: 24)
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
                            
                            Text("/")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            
                            // Day input
                            TextField("DD", text: $dayText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .frame(width: 24)
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
    
    init() {
        loadDeadlines()
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
    private var scrollEndTimer: Timer?
    
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
        // Only handle horizontal scrolling
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            onHorizontalScroll?(event.scrollingDeltaX)
            
            // Reset the timer for scroll end detection
            scrollEndTimer?.invalidate()
            scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                self.onScrollEnded?()
            }
        } else {
            // Pass vertical scrolling to the parent
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
