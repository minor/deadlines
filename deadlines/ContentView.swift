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
                        .frame(width: 60, height: 32)
                        .background(Color.red)
                }
                .opacity(showingDeleteButton ? 1 : 0)
            }
            
            // Main content
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
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow left swipe (negative translation)
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -60)
                            showingDeleteButton = offset < -30
                        }
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.2)) {
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
                    .padding(.top, 16)
                Spacer()
            }
            
            // Deadlines list
            VStack(spacing: 2) {
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
                                isEditingDeadlineName = true
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
                            Text("MM/DD")
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
            }
            .padding(.vertical, 8)
            
            // Separator
            Divider()
                .padding(.horizontal, 16)
            
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
        .frame(minWidth: 280, maxWidth: 280)
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
