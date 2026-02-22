//
//  PluginSettings.swift
//  KimiMailAssistant
//
//  Plugin management and configuration view.
//

import SwiftUI

struct PluginSettings: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedPlugin: Plugin?
    @State private var showingStore = false
    @State private var searchText = ""
    
    var filteredPlugins: [Plugin] {
        if searchText.isEmpty {
            return appState.availablePlugins
        }
        return appState.availablePlugins.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plugins")
                        .font(.title2.bold())
                    Text("\(appState.enabledPlugins.count) active of \(appState.availablePlugins.count) installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                SearchField(text: $searchText, placeholder: "Search plugins...")
                    .frame(width: 200)
                
                Button {
                    showingStore = true
                } label: {
                    Label("Plugin Store", systemImage: "cart")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Plugin List
            List(selection: $selectedPlugin) {
                Section("Enabled") {
                    ForEach(enabledPlugins) { plugin in
                        PluginSettingsRow(
                            plugin: plugin,
                            isEnabled: true,
                            onToggle: { appState.togglePlugin(plugin) },
                            onConfigure: { selectedPlugin = plugin }
                        )
                    }
                }
                
                Section("Available") {
                    ForEach(disabledPlugins) { plugin in
                        PluginSettingsRow(
                            plugin: plugin,
                            isEnabled: false,
                            onToggle: { appState.togglePlugin(plugin) },
                            onConfigure: nil
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .sheet(item: $selectedPlugin) { plugin in
            PluginConfigurationSheet(plugin: plugin)
        }
        .sheet(isPresented: $showingStore) {
            PluginStoreView()
        }
    }
    
    private var enabledPlugins: [Plugin] {
        filteredPlugins.filter { appState.isPluginEnabled($0) }
    }
    
    private var disabledPlugins: [Plugin] {
        filteredPlugins.filter { !appState.isPluginEnabled($0) }
    }
}

// MARK: - Plugin Settings Row

struct PluginSettingsRow: View {
    let plugin: Plugin
    let isEnabled: Bool
    let onToggle: () -> Void
    let onConfigure: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: plugin.icon)
                    .font(.title3)
                    .foregroundStyle(isEnabled ? .purple : .secondary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .semibold))
                    
                    if let badge = plugin.badge {
                        Text(badge)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                
                Text(plugin.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Text("v\(plugin.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if let author = plugin.author {
                        Text("by \(author)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if let onConfigure = onConfigure, plugin.isConfigurable {
                    Button {
                        onConfigure()
                    } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.borderless)
                }
                
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plugin Configuration Sheet

struct PluginConfigurationSheet: View {
    let plugin: Plugin
    @Environment(\.dismiss) private var dismiss
    @State private var settings: [String: Any] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: plugin.icon)
                            .font(.title2)
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plugin.name)
                                .font(.headline)
                            Text(plugin.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Configuration") {
                    // Dynamic configuration based on plugin manifest
                    ForEach(plugin.configOptions, id: \.key) { option in
                        ConfigOptionView(option: option, value: binding(for: option))
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        resetSettings()
                    }
                    .foregroundStyle(.red)
                }
                
                Section {
                    Button("Uninstall Plugin...") {
                        // Show confirmation
                    }
                    .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Configure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
    }
    
    private func binding(for option: ConfigOption) -> Binding<Any> {
        Binding(
            get: { settings[option.key] ?? option.defaultValue },
            set: { settings[option.key] = $0 }
        )
    }
    
    private func resetSettings() {
        settings = [:]
        for option in plugin.configOptions {
            settings[option.key] = option.defaultValue
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(settings, forKey: "plugin_settings_\(plugin.id)")
    }
}

struct ConfigOptionView: View {
    let option: ConfigOption
    @Binding var value: Any
    
    var body: some View {
        switch option.type {
        case .string:
            TextField(option.label, text: stringBinding)
        case .number:
            HStack {
                Text(option.label)
                Spacer()
                TextField("", value: numberBinding, format: .number)
                    .frame(width: 80)
            }
        case .boolean:
            Toggle(option.label, isOn: boolBinding)
        case .selection:
            Picker(option.label, selection: stringBinding) {
                ForEach(option.options ?? [], id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
        }
    }
    
    private var stringBinding: Binding<String> {
        Binding(
            get: { value as? String ?? "" },
            set: { value = $0 }
        )
    }
    
    private var numberBinding: Binding<Double> {
        Binding(
            get: { value as? Double ?? 0 },
            set: { value = $0 }
        )
    }
    
    private var boolBinding: Binding<Bool> {
        Binding(
            get: { value as? Bool ?? false },
            set: { value = $0 }
        )
    }
}

// MARK: - Plugin Store View

struct PluginStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: PluginCategory?
    @State private var plugins: [StorePlugin] = []
    
    var body: some View {
        NavigationStack {
            List {
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(PluginCategory.allCases) { category in
                            CategoryChip(
                                title: category.displayName,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Featured
                Section("Featured") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(featuredPlugins) { plugin in
                                FeaturedPluginCard(plugin: plugin)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // All Plugins
                Section("All Plugins") {
                    ForEach(filteredPlugins) { plugin in
                        StorePluginRow(plugin: plugin)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Plugin Store")
            .searchable(text: $searchText, prompt: "Search plugins...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
    
    private var filteredPlugins: [StorePlugin] {
        var result = plugins
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    private var featuredPlugins: [StorePlugin] {
        plugins.filter { $0.isFeatured }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct FeaturedPluginCard: View {
    let plugin: StorePlugin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(plugin.accentColor.opacity(0.2))
                    .frame(width: 200, height: 120)
                
                Image(systemName: plugin.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(plugin.accentColor)
            }
            
            Text(plugin.name)
                .font(.headline)
            
            Text(plugin.shortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.1f", plugin.rating))
                        .font(.caption)
                }
                
                Spacer()
                
                if plugin.isInstalled {
                    Text("Installed")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let price = plugin.price {
                    Text(price)
                        .font(.caption)
                        .fontWeight(.semibold)
                } else {
                    Text("Free")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(width: 200)
    }
}

struct StorePluginRow: View {
    let plugin: StorePlugin
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plugin.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(plugin.accentColor.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if plugin.isNew {
                        Text("NEW")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(plugin.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", plugin.rating))
                            .font(.caption)
                    }
                    
                    Text("\(plugin.downloadCount) downloads")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if plugin.isInstalled {
                Text("Installed")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(plugin.price != nil ? plugin.price! : "Get") {
                    // Install plugin
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

enum PluginCategory: String, CaseIterable, Identifiable {
    case productivity = "productivity"
    case security = "security"
    case organization = "organization"
    case communication = "communication"
    case ai = "ai"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .security: return "Security"
        case .organization: return "Organization"
        case .communication: return "Communication"
        case .ai: return "AI"
        }
    }
}

struct ConfigOption {
    let key: String
    let label: String
    let type: ConfigType
    let defaultValue: Any
    let options: [String]?
}

enum ConfigType {
    case string
    case number
    case boolean
    case selection
}

struct StorePlugin: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let shortDescription: String
    let icon: String
    let category: PluginCategory
    let accentColor: Color
    let rating: Double
    let downloadCount: Int
    let isFeatured: Bool
    let isNew: Bool
    let isInstalled: Bool
    let price: String?
}

// MARK: - Extensions

extension Plugin {
    var badge: String? { nil }
    var author: String? { nil }
    var isConfigurable: Bool { true }
    var configOptions: [ConfigOption] { [] }
}
