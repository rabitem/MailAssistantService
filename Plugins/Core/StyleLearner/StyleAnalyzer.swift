import Foundation
import PluginAPI

// MARK: - Style Scores

/// Computed style scores for a writing profile
public struct StyleScores: Codable, Sendable {
    /// Formality level (0.0 = very casual, 1.0 = very formal)
    public let formality: Double
    
    /// Friendliness level (0.0 = distant, 1.0 = very friendly)
    public let friendliness: Double
    
    /// Brevity level (0.0 = verbose, 1.0 = very concise)
    public let brevity: Double
    
    /// Directness level (0.0 = indirect, 1.0 = very direct)
    public let directness: Double
    
    /// Enthusiasm level (0.0 = reserved, 1.0 = very enthusiastic)
    public let enthusiasm: Double
    
    /// Technicality level (0.0 = simple, 1.0 = highly technical)
    public let technicality: Double
    
    /// Empathy level (0.0 = neutral, 1.0 = highly empathetic)
    public let empathy: Double
    
    /// Complexity level (0.0 = simple vocabulary, 1.0 = complex)
    public let complexity: Double
    
    public init(
        formality: Double = 0.5,
        friendliness: Double = 0.5,
        brevity: Double = 0.5,
        directness: Double = 0.5,
        enthusiasm: Double = 0.5,
        technicality: Double = 0.3,
        empathy: Double = 0.5,
        complexity: Double = 0.5
    ) {
        self.formality = max(0, min(1, formality))
        self.friendliness = max(0, min(1, friendliness))
        self.brevity = max(0, min(1, brevity))
        self.directness = max(0, min(1, directness))
        self.enthusiasm = max(0, min(1, enthusiasm))
        self.technicality = max(0, min(1, technicality))
        self.empathy = max(0, min(1, empathy))
        self.complexity = max(0, min(1, complexity))
    }
}

// MARK: - Aggregated Features

/// Features aggregated from multiple emails
public struct AggregatedFeatures: Codable, Sendable {
    public let totalEmailsAnalyzed: Int
    public let analysisDateRange: DateInterval?
    
    // Averaged metrics
    public let averageSentenceLength: Double
    public let averageWordLength: Double
    public let averageTypeTokenRatio: Double
    public let averageContractionRatio: Double
    public let averageParagraphLength: Double
    
    // Frequency distributions
    public let greetingPatterns: [String: Int]
    public let closingPatterns: [String: Int]
    public let commonPhrases: [String: Int]
    public let signatureLines: [String: Int]
    public let frequentWords: [String: Int]
    
    // Structural preferences
    public let greetingUsageRate: Double
    public let closingUsageRate: Double
    public let signatureUsageRate: Double
    public let bulletPointUsageRate: Double
    public let emojiUsageRate: Double
    
    public init(
        totalEmailsAnalyzed: Int = 0,
        analysisDateRange: DateInterval? = nil,
        averageSentenceLength: Double = 0,
        averageWordLength: Double = 0,
        averageTypeTokenRatio: Double = 0,
        averageContractionRatio: Double = 0,
        averageParagraphLength: Double = 0,
        greetingPatterns: [String: Int] = [:],
        closingPatterns: [String: Int] = [:],
        commonPhrases: [String: Int] = [:],
        signatureLines: [String: Int] = [:],
        frequentWords: [String: Int] = [:],
        greetingUsageRate: Double = 0,
        closingUsageRate: Double = 0,
        signatureUsageRate: Double = 0,
        bulletPointUsageRate: Double = 0,
        emojiUsageRate: Double = 0
    ) {
        self.totalEmailsAnalyzed = totalEmailsAnalyzed
        self.analysisDateRange = analysisDateRange
        self.averageSentenceLength = averageSentenceLength
        self.averageWordLength = averageWordLength
        self.averageTypeTokenRatio = averageTypeTokenRatio
        self.averageContractionRatio = averageContractionRatio
        self.averageParagraphLength = averageParagraphLength
        self.greetingPatterns = greetingPatterns
        self.closingPatterns = closingPatterns
        self.commonPhrases = commonPhrases
        self.signatureLines = signatureLines
        self.frequentWords = frequentWords
        self.greetingUsageRate = greetingUsageRate
        self.closingUsageRate = closingUsageRate
        self.signatureUsageRate = signatureUsageRate
        self.bulletPointUsageRate = bulletPointUsageRate
        self.emojiUsageRate = emojiUsageRate
    }
}

// MARK: - Style Analyzer

/// Analyzes extracted features to build writing profiles
public actor StyleAnalyzer {
    
    // MARK: - Constants
    
    private let minEmailsForAnalysis = 5
    private let phraseFrequencyThreshold = 3
    
    // MARK: - Properties
    
    private var aggregatedFeatures: AggregatedFeatures
    
    // MARK: - Initialization
    
    public init() {
        self.aggregatedFeatures = AggregatedFeatures()
    }
    
    // MARK: - Analysis
    
    /// Analyze a batch of extracted features to build a writing profile
    public func analyzeFeatures(_ features: [ExtractedFeatures]) -> WritingStyle {
        guard features.count >= minEmailsForAnalysis else {
            // Return default style if insufficient data
            return createDefaultStyle()
        }
        
        aggregatedFeatures = aggregateFeatures(features)
        let scores = calculateStyleScores(features: features, aggregated: aggregatedFeatures)
        
        return buildWritingStyle(scores: scores, aggregated: aggregatedFeatures)
    }
    
    /// Update analysis with new features
    public func updateAnalysis(with newFeatures: ExtractedFeatures) {
        // This would update the aggregated features incrementally
        // For now, we'll just store this for batch processing
    }
    
    /// Get the current aggregated features
    public func getAggregatedFeatures() -> AggregatedFeatures {
        return aggregatedFeatures
    }
    
    // MARK: - Feature Aggregation
    
    private func aggregateFeatures(_ features: [ExtractedFeatures]) -> AggregatedFeatures {
        let count = features.count
        guard count > 0 else { return AggregatedFeatures() }
        
        // Calculate averages
        let avgSentenceLength = features.map(\.averageSentenceLength).reduce(0, +) / Double(count)
        let avgWordLength = features.map(\.averageWordLength).reduce(0, +) / Double(count)
        let avgTypeTokenRatio = features.map(\.typeTokenRatio).reduce(0, +) / Double(count)
        let avgContractionRatio = features.map(\.contractionRatio).reduce(0, +) / Double(count)
        let avgParagraphLength = features.map(\.averageParagraphLength).reduce(0, +) / Double(count)
        
        // Aggregate patterns
        var greetingPatterns: [String: Int] = [:]
        var closingPatterns: [String: Int] = [:]
        var allPhrases: [String: Int] = [:]
        var allSignatures: [String: Int] = [:]
        
        for feature in features {
            if let greeting = feature.greetingPattern {
                greetingPatterns[greeting, default: 0] += 1
            }
            if let closing = feature.closingPattern {
                closingPatterns[closing, default: 0] += 1
            }
            for phrase in feature.commonPhrases {
                allPhrases[phrase, default: 0] += 1
            }
            for signature in feature.signatureLines {
                allSignatures[signature, default: 0] += 1
            }
        }
        
        // Calculate usage rates
        let greetingRate = Double(features.filter(\.hasGreeting).count) / Double(count)
        let closingRate = Double(features.filter(\.hasClosing).count) / Double(count)
        let signatureRate = Double(features.filter(\.hasSignature).count) / Double(count)
        let bulletRate = Double(features.filter(\.usesBulletPoints).count) / Double(count)
        let emojiRate = Double(features.filter(\.usesEmojis).count) / Double(count)
        
        // Get date range
        let dates = features.map(\.extractedAt)
        let dateRange = dates.isEmpty ? nil : DateInterval(start: dates.min()!, end: dates.max()!)
        
        return AggregatedFeatures(
            totalEmailsAnalyzed: count,
            analysisDateRange: dateRange,
            averageSentenceLength: avgSentenceLength,
            averageWordLength: avgWordLength,
            averageTypeTokenRatio: avgTypeTokenRatio,
            averageContractionRatio: avgContractionRatio,
            averageParagraphLength: avgParagraphLength,
            greetingPatterns: greetingPatterns,
            closingPatterns: closingPatterns,
            commonPhrases: filterCommonPhrases(allPhrases, threshold: phraseFrequencyThreshold),
            signatureLines: allSignatures,
            frequentWords: [:], // Would need word frequency analysis
            greetingUsageRate: greetingRate,
            closingUsageRate: closingRate,
            signatureUsageRate: signatureRate,
            bulletPointUsageRate: bulletRate,
            emojiUsageRate: emojiRate
        )
    }
    
    private func filterCommonPhrases(_ phrases: [String: Int], threshold: Int) -> [String: Int] {
        return phrases.filter { $0.value >= threshold }
    }
    
    // MARK: - Score Calculation
    
    private func calculateStyleScores(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> StyleScores {
        return StyleScores(
            formality: calculateFormalityScore(features: features, aggregated: aggregated),
            friendliness: calculateFriendlinessScore(features: features, aggregated: aggregated),
            brevity: calculateBrevityScore(features: features, aggregated: aggregated),
            directness: calculateDirectnessScore(features: features, aggregated: aggregated),
            enthusiasm: calculateEnthusiasmScore(features: features, aggregated: aggregated),
            technicality: calculateTechnicalityScore(features: features, aggregated: aggregated),
            empathy: calculateEmpathyScore(features: features, aggregated: aggregated),
            complexity: calculateComplexityScore(features: features, aggregated: aggregated)
        )
    }
    
    private func calculateFormalityScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Contraction usage (inverse - fewer contractions = more formal)
        score -= aggregated.averageContractionRatio * 0.3
        
        // Greeting patterns
        let formalGreetings = aggregated.greetingPatterns.keys.filter { greeting in
            greeting.lowercased().contains("dear") || 
            greeting.lowercased().contains("to whom")
        }.count
        let formalGreetingRate = Double(formalGreetings) / max(Double(aggregated.greetingPatterns.count), 1)
        score += formalGreetingRate * 0.2
        
        // Closing patterns
        let formalClosings = aggregated.closingPatterns.keys.filter { closing in
            closing.lowercased().contains("regards") || 
            closing.lowercased().contains("sincerely")
        }.count
        let formalClosingRate = Double(formalClosings) / max(Double(aggregated.closingPatterns.count), 1)
        score += formalClosingRate * 0.2
        
        // Emoji usage (inverse)
        score -= aggregated.emojiUsageRate * 0.3
        
        // Word length (longer words = more formal)
        let normalizedWordLength = min(aggregated.averageWordLength / 6.0, 1.0)
        score += normalizedWordLength * 0.1
        
        return max(0, min(1, score))
    }
    
    private func calculateFriendlinessScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Contraction usage (friendly = more contractions)
        score += aggregated.averageContractionRatio * 0.25
        
        // Exclamation usage
        let avgExclamations = features.map(\.exclamationRatio).reduce(0, +) / Double(features.count)
        score += min(avgExclamations * 2, 0.2)
        
        // Greeting usage rate
        score += aggregated.greetingUsageRate * 0.15
        
        // Closing usage rate
        score += aggregated.closingUsageRate * 0.1
        
        // Emoji usage
        score += aggregated.emojiUsageRate * 0.2
        
        // Informal greetings
        let informalGreetings = aggregated.greetingPatterns.keys.filter { greeting in
            greeting.lowercased().contains("hey") || greeting.lowercased().contains("hi")
        }.count
        let informalRate = Double(informalGreetings) / max(Double(aggregated.greetingPatterns.count), 1)
        score += informalRate * 0.1
        
        return max(0, min(1, score))
    }
    
    private func calculateBrevityScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Sentence length (shorter = more brief)
        let avgSentenceLength = aggregated.averageSentenceLength
        if avgSentenceLength < 10 {
            score += 0.3
        } else if avgSentenceLength > 20 {
            score -= 0.3
        } else {
            score += (15 - avgSentenceLength) / 15 * 0.3
        }
        
        // Word length (shorter words = more brief)
        if aggregated.averageWordLength < 4.5 {
            score += 0.15
        } else if aggregated.averageWordLength > 5.5 {
            score -= 0.15
        }
        
        // Paragraph length
        if aggregated.averageParagraphLength < 2 {
            score += 0.2
        } else if aggregated.averageParagraphLength > 5 {
            score -= 0.2
        }
        
        // Use of bullet points (indicates conciseness)
        score += aggregated.bulletPointUsageRate * 0.15
        
        return max(0, min(1, score))
    }
    
    private func calculateDirectnessScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Sentence length (shorter = more direct)
        if aggregated.averageSentenceLength < 15 {
            score += 0.25
        } else {
            score -= 0.1
        }
        
        // Questions (asking questions = less direct)
        let avgQuestions = features.map(\.questionRatio).reduce(0, +) / Double(features.count)
        score -= avgQuestions * 0.2
        
        // Type-token ratio (lower = more repetitive/direct)
        score += (1 - aggregated.averageTypeTokenRatio) * 0.15
        
        // Transition phrases (more transitions = less direct)
        let transitionCount = features.reduce(0) { $0 + $1.transitionPhrases.count }
        let avgTransitions = Double(transitionCount) / Double(features.count)
        score -= min(avgTransitions / 5, 0.15)
        
        return max(0, min(1, score))
    }
    
    private func calculateEnthusiasmScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Exclamation usage
        let avgExclamations = features.map(\.exclamationRatio).reduce(0, +) / Double(features.count)
        score += min(avgExclamations * 3, 0.4)
        
        // Emoji usage
        score += aggregated.emojiUsageRate * 0.3
        
        // Contraction usage
        score += aggregated.averageContractionRatio * 0.1
        
        // Closing enthusiasm
        let enthusiasticClosings = aggregated.closingPatterns.keys.filter { closing in
            closing.lowercased().contains("cheers") || 
            closing.lowercased().contains("excited") ||
            closing.lowercased().contains("looking forward")
        }.count
        let enthusiasmRate = Double(enthusiasticClosings) / max(Double(aggregated.closingPatterns.count), 1)
        score += enthusiasmRate * 0.2
        
        return max(0, min(1, score))
    }
    
    private func calculateTechnicalityScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.3 // Start lower (default assumption)
        
        // Word length (longer = more technical)
        score += (aggregated.averageWordLength - 4.0) / 3.0 * 0.3
        
        // Type-token ratio (higher = more diverse vocabulary = more technical)
        score += aggregated.averageTypeTokenRatio * 0.2
        
        // Sentence length (longer = more technical)
        if aggregated.averageSentenceLength > 20 {
            score += 0.2
        }
        
        // Formality (technical writing is often formal)
        score += calculateFormalityScore(features: features, aggregated: aggregated) * 0.3
        
        return max(0, min(1, score))
    }
    
    private func calculateEmpathyScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Empathetic phrases in common phrases
        let empatheticPhrases = ["understand", "sorry", "appreciate", "thank", "feel"]
        let empatheticCount = aggregated.commonPhrases.keys.filter { phrase in
            empatheticPhrases.contains { phrase.lowercased().contains($0) }
        }.count
        score += Double(empatheticCount) / 10.0 * 0.3
        
        // Question usage (shows interest)
        let avgQuestions = features.map(\.questionRatio).reduce(0, +) / Double(features.count)
        score += min(avgQuestions * 2, 0.2)
        
        // Exclamation usage (enthusiasm can indicate empathy)
        let avgExclamations = features.map(\.exclamationRatio).reduce(0, +) / Double(features.count)
        score += min(avgExclamations, 0.1)
        
        return max(0, min(1, score))
    }
    
    private func calculateComplexityScore(features: [ExtractedFeatures], aggregated: AggregatedFeatures) -> Double {
        var score = 0.5
        
        // Word length
        score += (aggregated.averageWordLength - 4.0) / 3.0 * 0.3
        
        // Type-token ratio
        score += aggregated.averageTypeTokenRatio * 0.25
        
        // Sentence length
        if aggregated.averageSentenceLength > 15 {
            score += min((aggregated.averageSentenceLength - 15) / 15, 0.25)
        } else {
            score -= (15 - aggregated.averageSentenceLength) / 15 * 0.2
        }
        
        // Paragraph length
        if aggregated.averageParagraphLength > 4 {
            score += 0.1
        }
        
        return max(0, min(1, score))
    }
    
    // MARK: - Writing Style Builder
    
    private func buildWritingStyle(scores: StyleScores, aggregated: AggregatedFeatures) -> WritingStyle {
        let tone = ToneCharacteristics(
            friendliness: scores.friendliness,
            directness: scores.directness,
            enthusiasm: scores.enthusiasm,
            humor: 0.0, // Would need more sophisticated analysis
            empathy: scores.empathy,
            technicality: scores.technicality
        )
        
        let vocabulary = VocabularyCharacteristics(
            complexity: scores.complexity,
            jargon: scores.technicality,
            contractions: aggregated.averageContractionRatio,
            averageSentenceLength: aggregated.averageSentenceLength,
            averageWordLength: aggregated.averageWordLength,
            frequentWords: Array(aggregated.frequentWords.sorted { $0.value > $1.value }.prefix(20).map(\.key)),
            avoidedWords: []
        )
        
        let structure = StructuralCharacteristics(
            averageParagraphLength: aggregated.averageParagraphLength,
            usesLists: aggregated.bulletPointUsageRate > 0.3,
            includesGreeting: aggregated.greetingUsageRate > 0.5,
            includesSignature: aggregated.signatureUsageRate > 0.5,
            usesHeaders: false, // Would need header detection
            greetingStyle: determineGreetingStyle(from: aggregated.greetingPatterns),
            signatureStyle: determineSignatureStyle(from: aggregated.signatureLines)
        )
        
        let formality = determineFormalityLevel(from: scores.formality)
        
        let topOpenings = aggregated.greetingPatterns
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
        
        let topClosings = aggregated.closingPatterns
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
        
        let topTransitions = aggregated.commonPhrases
            .filter { phrase, _ in
                ["however", "therefore", "furthermore", "additionally", "meanwhile"].contains { phrase.contains($0) }
            }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
        
        return WritingStyle(
            name: "Learned Style",
            description: "Writing style learned from \(aggregated.totalEmailsAnalyzed) sent emails",
            tone: tone,
            vocabulary: vocabulary,
            structure: structure,
            formality: formality,
            commonOpenings: topOpenings,
            commonClosings: topClosings,
            transitionPhrases: topTransitions,
            exampleEmails: [],
            sourceEmailsCount: aggregated.totalEmailsAnalyzed
        )
    }
    
    private func determineFormalityLevel(from score: Double) -> FormalityLevel {
        switch score {
        case 0.0..<0.2:
            return .casual
        case 0.2..<0.4:
            return .semiCasual
        case 0.4..<0.6:
            return .neutral
        case 0.6..<0.8:
            return .semiFormal
        default:
            return .formal
        }
    }
    
    private func determineGreetingStyle(from patterns: [String: Int]) -> GreetingStyle {
        guard !patterns.isEmpty else { return .none }
        
        let topPattern = patterns.max { $0.value < $1.value }?.key.lowercased() ?? ""
        
        if topPattern.contains("dear") {
            return .dearName
        } else if topPattern.contains("hi") {
            return .hiName
        } else if topPattern.contains("hello") {
            return .helloName
        } else if topPattern.contains("hey") {
            return .hiThere
        } else {
            return .nameOnly
        }
    }
    
    private func determineSignatureStyle(from signatures: [String: Int]) -> SignatureStyle {
        guard !signatures.isEmpty else { return .none }
        
        let topSignature = signatures.max { $0.value < $1.value }?.key.lowercased() ?? ""
        
        if topSignature.contains("best") {
            return .bestName
        } else if topSignature.contains("regards") {
            return .regardsName
        } else if topSignature.contains("thank") {
            return .thanksName
        } else if topSignature.contains("cheers") {
            return .cheersName
        } else {
            return .nameOnly
        }
    }
    
    private func createDefaultStyle() -> WritingStyle {
        return WritingStyle(
            name: "Default Style",
            description: "Default writing style - not enough emails analyzed yet",
            tone: ToneCharacteristics(friendliness: 0.5, directness: 0.5),
            vocabulary: VocabularyCharacteristics(),
            structure: StructuralCharacteristics(),
            formality: .neutral,
            sourceEmailsCount: 0
        )
    }
}

// MARK: - Profile Type

/// Type of writing profile to learn
public enum ProfileType: String, Codable, Sendable, CaseIterable {
    case personal = "personal"
    case work = "work"
    case mixed = "mixed"
    
    public var displayName: String {
        switch self {
        case .personal:
            return "Personal"
        case .work:
            return "Work"
        case .mixed:
            return "Mixed"
        }
    }
}
