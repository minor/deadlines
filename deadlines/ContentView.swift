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
        return calendar.dateComponents([.day], from: today, to: deadlineDate).day ?? 0
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Deadlines")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }
            
            // Deadlines list
            VStack(alignment: .leading, spacing: 4) {
                // Add deadline row (when adding)
                if isAddingDeadline {
                    HStack {
                        TextField("Deadline Name...", text: $newDeadlineName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .onSubmit {
                                if !newDeadlineName.isEmpty {
                                    showDatePicker = true
                                }
                            }
                        
                        Spacer()
                        
                        if showDatePicker {
                            DatePicker("", selection: $newDeadlineDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(CompactDatePickerStyle())
                                .font(.system(size: 14))
                                .onChange(of: newDeadlineDate) {
                                    // Auto-save when date is selected
                                    if !newDeadlineName.isEmpty {
                                        deadlineManager.addDeadline(name: newDeadlineName, date: newDeadlineDate)
                                        resetAddDeadlineState()
                                    }
                                }
                        } else {
                            Text("DD/MM")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .onTapGesture {
                                    if !newDeadlineName.isEmpty {
                                        showDatePicker = true
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                
                // Existing deadlines
                ForEach(deadlineManager.sortedDeadlines) { deadline in
                    HStack {
                        if editingDeadlineId == deadline.id {
                            TextField("Deadline name", text: $editingText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                                .onSubmit {
                                    deadlineManager.updateDeadlineName(id: deadline.id, newName: editingText)
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
                        
                        Text("\(deadline.daysUntil) days")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
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
                .padding(.vertical, 8)
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
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 280)
        .background(VisualEffectView())
    }
    
    private func resetAddDeadlineState() {
        isAddingDeadline = false
        showDatePicker = false
        newDeadlineName = ""
        newDeadlineDate = Date()
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
        deadlines.sorted { $0.daysUntil < $1.daysUntil }
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

#Preview {
    MenuBarView()
}
