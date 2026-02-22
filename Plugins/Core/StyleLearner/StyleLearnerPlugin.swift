import Foundation
import PluginAPI
import Shared

// MARK: - Style Learner Plugin

/// Plugin that learns the user's writing style from sent emails
public final actor StyleLearnerPlugin: AnalysisPlugin, EventSubscriber {
    
    // MARK: - Plugin Properties
    
    public static let pluginIdentifier = "core.style.learner"
    public static let displayName = "Style Learner"
    public static let version = "1.0.0"
    public static let description = "Analyzes sent emails to build a personalized writing style profile"
    public static let pluginType: PluginType = .analysis
    public static let requiredPermissions: [PluginPermission] = [
        .readEmails,
        .modifyWritingProfiles,
        .backgroundExecution,
        .pluginStorage
    ]
    
    public var context: PluginContext
    public var supportedAnalysisTypes: [AnalysisType] {
        [.tone]
    }
    
    public var subscriberID: String {
        "\(Self.pluginIdentifier).subscriber"
    }
    
    public var subscribedEvents: [MailEventType] {
        [.emailSent]
    }
    
    // MARK: - Private Properties
    
    private var featureExtractor: FeatureExtractor
    private var styleAnalyzer: StyleAnalyzer
    private var pendingFeatures: [ExtractedFeatures] = []
    private var profiles: [ProfileType: WritingProfile] = [:]
    private var isProcessing = false
    private var processingTask: Task<Void, Never>?
    private var retrainingTimer: Timer?
    
    // Configuration
    private var minEmailsForProfile: Int = 10
    private var batchSize: Int = 50
    private var retrainingInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Initialization
    
    public init(context: PluginContext) async throws {
        self.context = context
        self.featureExtractor = FeatureExtractor()
        self.styleAnalyzer = StyleAnalyzer()
        
        // Load saved configuration
        await loadConfiguration()
        
        // Load existing profiles
        await loadProfiles()
        
        context.logger.info("StyleLearnerPlugin initialized")
    }
    
    // MARK: - Plugin Protocol
    
    public func activate() async throws {
        context.logger.info("StyleLearnerPlugin activating...")
        
        // Subscribe to email events
        await context.eventBus.subscribe(self)
        
        // Start background processing
        startBackgroundProcessing()
        
        // Schedule periodic re-training
        scheduleRetraining()
        
        context.logger.info("StyleLearnerPlugin activated successfully")
    }
    
    public func deactivate() async throws {
        context.logger.info("StyleLearnerPlugin deactivating...")
        
        // Cancel background tasks
        processingTask?.cancel()
        retrainingTimer?.invalidate()
        
        // Unsubscribe from events
        await context.eventBus.unsubscribe(subscriberID)
        
        // Save profiles
        await saveProfiles()
        
        context.logger.info("StyleLearnerPlugin deactivated")
    }
    
    public func updateConfiguration(_ configuration: [String: AnyCodable]) async throws {
        if let minEmails = configuration["minEmailsForProfile"]?.value as? Int {
            minEmailsForProfile = max(5, minEmails)
        }
        
        if let batch = configuration["batchSize"]?.value as? Int {
            batchSize = max(10, batch)
        }
        
        if let interval = configuration["retrainingIntervalDays"]?.value as? Double {
            retrainingInterval = interval * 24 * 60 * 60
            scheduleRetraining()
        }
        
        await saveConfiguration()
        context.logger.info("Configuration updated")
    }
    
    // MARK: - AnalysisPlugin Protocol
    
    public func analyze(email: Email, types: [AnalysisType]) async throws -> AnalysisResult {
        let startTime = Date()
        
        // Extract features from the email
        let features = await featureExtractor.extractFeatures(from: email)
        
        // Get current profile for comparison/analysis
        let profile = getCurrentProfile()
        let style = profile?.defaultStyle
        
        // Create insights based on the analysis
        var insights: [Insight] = []
        
        if types.contains(.tone) {
            let toneInsight = createToneInsight(features: features, style: style)
            insights.append(toneInsight)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AnalysisResult(
            emailID: email.id,
            pluginID: Self.pluginIdentifier,
            insights: insights,
            processingTime: processingTime,
            confidence: 0.85
        )
    }
    
    public func analyzeBatch(emails: [Email], types: [AnalysisType]) async throws -> [AnalysisResult] {
        var results: [AnalysisResult] = []
        
        for email in emails {
            do {
                let result = try await analyze(email: email, types: types)
                results.append(result)
            } catch {
                context.logger.error("Failed to analyze email \(email.id): \(error.localizedDescription)")
            }
        }
        
        return results
    }
    
    public func canAnalyze(_ email: Email) async -> Bool {
        // Can analyze if email has content
        return !(email.bodyPlain?.isEmpty ?? true) || !email.preview.isEmpty
    }
    
    public func estimatedProcessingTime(for email: Email) -> TimeInterval {
        let wordCount = (email.bodyPlain ?? email.preview).split(separator: " ").count
        // Rough estimate: ~0.1ms per word
        return Double(wordCount) * 0.0001 + 0.05
    }
    
    // MARK: - EventSubscriber Protocol
    
    public func handleEvent(_ event: MailEvent) async {
        switch event {
        case .emailSent(let email):
            await handleEmailSent(email)
        default:
            break
        }
    }
    
    private func handleEmailSent(_ email: Email) async {
        context.logger.debug("Processing sent email: \(email.id)")
        
        // Extract features
        let features = await featureExtractor.extractFeatures(from: email)
        
        // Add to pending features
        pendingFeatures.append(features)
        
        // Trigger batch processing if we have enough features
        if pendingFeatures.count >= batchSize && !isProcessing {
            triggerBatchProcessing()
        }
        
        // Save features for persistence
        await saveFeatures()
    }
    
    // MARK: - Background Processing
    
    private func startBackgroundProcessing() {
        processingTask = Task {
            while !Task.isCancelled {
                if pendingFeatures.count >= minEmailsForProfile && !isProcessing {
                    await processPendingFeatures()
                }
                
                // Wait before checking again
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000) // 1 hour
            }
        }
    }
    
    private func triggerBatchProcessing() {
        Task {
            await processPendingFeatures()
        }
    }
    
    private func processPendingFeatures() async {
        guard !isProcessing, pendingFeatures.count >= minEmailsForProfile else { return }
        
        isProcessing = true
        let featuresToProcess = pendingFeatures
        
        context.logger.info("Processing \(featuresToProcess.count) emails for style analysis...")
        
        do {
            // Analyze features
            let style = await styleAnalyzer.analyzeFeatures(featuresToProcess)
            
            // Determine profile type based on features
            let profileType = determineProfileType(for: featuresToProcess)
            
            // Update or create profile
            await updateProfile(type: profileType, style: style, features: featuresToProcess)
            
            // Clear processed features
            pendingFeatures.removeAll()
            
            // Publish event
            if let profile = profiles[profileType] {
                await context.eventBus.publish(.writingStyleAnalyzed(
                    emailID: featuresToProcess.first?.emailID ?? UUID(),
                    profile: profile
                ))
            }
            
            context.logger.info("Style profile updated successfully")
            
        } catch {
            context.logger.error("Style analysis failed: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    private func determineProfileType(for features: [ExtractedFeatures]) -> ProfileType {
        // Analyze aggregated features to determine if this is work or personal
        let aggregated = await styleAnalyzer.getAggregatedFeatures()
        
        // Heuristics for work vs personal:
        // Work: Higher formality, more structured, less emoji usage
        // Personal: Lower formality, more casual language, more emoji
        
        let formalityScore = aggregated.averageContractionRatio < 0.1 ? 1 : 0
        let structureScore = aggregated.bulletPointUsageRate > 0.5 ? 1 : 0
        let casualScore = aggregated.emojiUsageRate > 0.3 ? 1 : 0
        
        let workScore = formalityScore + structureScore - casualScore
        
        return workScore > 0 ? .work : .personal
    }
    
    private func updateProfile(type: ProfileType, style: WritingStyle, features: [ExtractedFeatures]) async {
        let now = Date()
        
        if var existingProfile = profiles[type] {
            // Update existing profile
            var updatedStyle = style
            // Merge with existing style
            updatedStyle = mergeStyles(existing: existingProfile.defaultStyle, new: style)
            
            profiles[type] = WritingProfile(
                id: existingProfile.id,
                userID: existingProfile.userID,
                name: existingProfile.name,
                isDefault: existingProfile.isDefault,
                defaultStyle: updatedStyle,
                contextualStyles: existingProfile.contextualStyles,
                contactStyles: existingProfile.contactStyles,
                createdAt: existingProfile.createdAt,
                updatedAt: now
            )
        } else {
            // Create new profile
            profiles[type] = WritingProfile(
                userID: context.pluginID.uuidString,
                name: "\(type.displayName) Style",
                isDefault: profiles.isEmpty,
                defaultStyle: style,
                createdAt: now,
                updatedAt: now
            )
        }
        
        await saveProfiles()
    }
    
    private func mergeStyles(existing: WritingStyle, new: WritingStyle) -> WritingStyle {
        // Weighted average based on source email counts
        let existingWeight = Double(existing.sourceEmailsCount)
        let newWeight = Double(new.sourceEmailsCount)
        let totalWeight = existingWeight + newWeight
        
        guard totalWeight > 0 else { return new }
        
        let weight1 = existingWeight / totalWeight
        let weight2 = newWeight / totalWeight
        
        let mergedTone = ToneCharacteristics(
            friendliness: existing.tone.friendliness * weight1 + new.tone.friendliness * weight2,
            directness: existing.tone.directness * weight1 + new.tone.directness * weight2,
            enthusiasm: existing.tone.enthusiasm * weight1 + new.tone.enthusiasm * weight2,
            humor: existing.tone.humor * weight1 + new.tone.humor * weight2,
            empathy: existing.tone.empathy * weight1 + new.tone.empathy * weight2,
            technicality: existing.tone.technicality * weight1 + new.tone.technicality * weight2
        )
        
        let mergedVocabulary = VocabularyCharacteristics(
            complexity: existing.vocabulary.complexity * weight1 + new.vocabulary.complexity * weight2,
            jargon: existing.vocabulary.jargon * weight1 + new.vocabulary.jargon * weight2,
            contractions: existing.vocabulary.contractions * weight1 + new.vocabulary.contractions * weight2,
            averageSentenceLength: existing.vocabulary.averageSentenceLength * weight1 + new.vocabulary.averageSentenceLength * weight2,
            averageWordLength: existing.vocabulary.averageWordLength * weight1 + new.vocabulary.averageWordLength * weight2,
            frequentWords: mergeFrequentWords(existing.vocabulary.frequentWords, new.vocabulary.frequentWords),
            avoidedWords: existing.vocabulary.avoidedWords
        )
        
        // For structural characteristics, use the newer style's preferences if significantly different
        let mergedStructure = existing.structure // Keep existing structure preferences
        
        return WritingStyle(
            id: existing.id,
            name: existing.name,
            description: "\(existing.description ?? "") (Updated)",
            tone: mergedTone,
            vocabulary: mergedVocabulary,
            structure: mergedStructure,
            formality: new.formality, // Use new formality level
            commonOpenings: mergeUnique(existing.commonOpenings, new.commonOpenings),
            commonClosings: mergeUnique(existing.commonClosings, new.commonClosings),
            transitionPhrases: mergeUnique(existing.transitionPhrases, new.transitionPhrases),
            exampleEmails: existing.exampleEmails,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            sourceEmailsCount: existing.sourceEmailsCount + new.sourceEmailsCount
        )
    }
    
    private func mergeFrequentWords(_ existing: [String], _ new: [String]) -> [String] {
        var combined = Set(existing).union(Set(new))
        return Array(combined).prefix(20).map { $0 }
    }
    
    private func mergeUnique<T: Hashable>(_ existing: [T], _ new: [T]) -> [T] {
        var combined = Array(Set(existing).union(Set(new)))
        return Array(combined.prefix(10))
    }
    
    // MARK: - Retraining
    
    private func scheduleRetraining() {
        retrainingTimer?.invalidate()
        
        retrainingTimer = Timer.scheduledTimer(withTimeInterval: retrainingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performRetraining()
            }
        }
    }
    
    private func performRetraining() async {
        context.logger.info("Starting periodic style retraining...")
        
        // Load historical features and re-analyze
        await loadFeatures()
        
        if pendingFeatures.count >= minEmailsForProfile {
            await processPendingFeatures()
        }
        
        context.logger.info("Periodic retraining complete")
    }
    
    // MARK: - Profile Access
    
    /// Get the default writing profile
    public func getCurrentProfile() -> WritingProfile? {
        return profiles.values.first { $0.isDefault } ?? profiles.values.first
    }
    
    /// Get a specific profile type
    public func getProfile(type: ProfileType) -> WritingProfile? {
        return profiles[type]
    }
    
    /// Get all available profiles
    public func getAllProfiles() -> [WritingProfile] {
        return Array(profiles.values)
    }
    
    /// Set the default profile
    public func setDefaultProfile(type: ProfileType) async {
        for (key, var profile) in profiles {
            profile = WritingProfile(
                id: profile.id,
                userID: profile.userID,
                name: profile.name,
                isDefault: (key == type),
                defaultStyle: profile.defaultStyle,
                contextualStyles: profile.contextualStyles,
                contactStyles: profile.contactStyles,
                createdAt: profile.createdAt,
                updatedAt: Date()
            )
            profiles[key] = profile
        }
        
        await saveProfiles()
    }
    
    // MARK: - Persistence
    
    private func saveConfiguration() async {
        let config: [String: AnyCodable] = [
            "minEmailsForProfile": AnyCodable(minEmailsForProfile),
            "batchSize": AnyCodable(batchSize),
            "retrainingIntervalDays": AnyCodable(retrainingInterval / (24 * 60 * 60))
        ]
        
        do {
            try await context.storage.write(key: "configuration", value: config)
        } catch {
            context.logger.error("Failed to save configuration: \(error.localizedDescription)")
        }
    }
    
    private func loadConfiguration() async {
        do {
            if let config: [String: AnyCodable] = try await context.storage.read(key: "configuration") {
                if let minEmails = config["minEmailsForProfile"]?.value as? Int {
                    minEmailsForProfile = minEmails
                }
                if let batch = config["batchSize"]?.value as? Int {
                    batchSize = batch
                }
                if let interval = config["retrainingIntervalDays"]?.value as? Double {
                    retrainingInterval = interval * 24 * 60 * 60
                }
            }
        } catch {
            context.logger.warning("Failed to load configuration: \(error.localizedDescription)")
        }
    }
    
    private func saveProfiles() async {
        do {
            try await context.storage.write(key: "profiles", value: profiles)
        } catch {
            context.logger.error("Failed to save profiles: \(error.localizedDescription)")
        }
    }
    
    private func loadProfiles() async {
        do {
            if let loaded: [ProfileType: WritingProfile] = try await context.storage.read(key: "profiles") {
                profiles = loaded
                context.logger.info("Loaded \(profiles.count) writing profiles")
            }
        } catch {
            context.logger.warning("Failed to load profiles: \(error.localizedDescription)")
        }
    }
    
    private func saveFeatures() async {
        do {
            try await context.storage.write(key: "pendingFeatures", value: pendingFeatures)
        } catch {
            context.logger.error("Failed to save features: \(error.localizedDescription)")
        }
    }
    
    private func loadFeatures() async {
        do {
            if let loaded: [ExtractedFeatures] = try await context.storage.read(key: "pendingFeatures") {
                pendingFeatures = loaded
                context.logger.info("Loaded \(pendingFeatures.count) pending features")
            }
        } catch {
            context.logger.warning("Failed to load features: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Insight Creation
    
    private func createToneInsight(features: ExtractedFeatures, style: WritingStyle?) -> Insight {
        let title = "Writing Style Analysis"
        let description: String
        let value: InsightValue
        
        if let style = style {
            let formalityDescription: String
            switch style.formality {
            case .casual:
                formalityDescription = "casual and relaxed"
            case .semiCasual:
                formalityDescription = "mostly casual"
            case .neutral:
                formalityDescription = "balanced"
            case .semiFormal:
                formalityDescription = "mostly formal"
            case .formal:
                formalityDescription = "very formal"
            }
            
            description = """
            Your writing style is \(formalityDescription).
            Average sentence length: \(String(format: "%.1f", style.vocabulary.averageSentenceLength)) words.
            You use \(style.structure.includesGreeting ? "greetings" : "no greetings") and \
            \(style.structure.includesSignature ? "signatures" : "no signatures") in your emails.
            """
            
            value = .dictionary([
                "formality": .string(style.formality.rawValue),
                "friendliness": .double(style.tone.friendliness),
                "directness": .double(style.tone.directness),
                "complexity": .double(style.vocabulary.complexity),
                "avgSentenceLength": .double(style.vocabulary.averageSentenceLength)
            ])
        } else {
            description = "Not enough emails analyzed to determine your writing style yet."
            value = .none
        }
        
        return Insight(
            type: .tone,
            title: title,
            description: description,
            value: value,
            confidence: style != nil ? 0.85 : 0.0,
            metadata: [
                "emailID": AnyCodable(features.emailID.uuidString),
                "wordCount": AnyCodable(features.wordCount)
            ]
        )
    }
}

// MARK: - Timer Extension for Swift Concurrency

extension Timer {
    static func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping @Sendable (Timer) -> Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: interval, target: TimerTarget(block: block), selector: #selector(TimerTarget.fire), userInfo: nil, repeats: repeats)
    }
}

private final class TimerTarget: @unchecked Sendable {
    let block: (Timer) -> Void
    
    init(block: @escaping (Timer) -> Void) {
        self.block = block
    }
    
    @objc func fire(timer: Timer) {
        block(timer)
    }
}
