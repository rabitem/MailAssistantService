import Foundation
import PluginAPI

// MARK: - Extracted Features

/// Features extracted from a single email for style analysis
public struct ExtractedFeatures: Codable, Sendable {
    public let emailID: UUID
    public let extractedAt: Date
    
    // MARK: - Sentence Metrics
    
    public let averageSentenceLength: Double
    public let sentenceCount: Int
    public let sentenceLengthDistribution: [Int]
    
    // MARK: - Word Metrics
    
    public let averageWordLength: Double
    public let wordCount: Int
    public let uniqueWordCount: Int
    public let typeTokenRatio: Double
    
    // MARK: - Formality Markers
    
    public let contractionCount: Int
    public let contractionRatio: Double
    public let formalWordCount: Int
    public let informalWordCount: Int
    public let slangWords: [String]
    
    // MARK: - Structure
    
    public let paragraphCount: Int
    public let averageParagraphLength: Double
    public let hasGreeting: Bool
    public let hasClosing: Bool
    public let hasSignature: Bool
    public let usesBulletPoints: Bool
    
    // MARK: - Patterns
    
    public let greetingPattern: String?
    public let closingPattern: String?
    public let signatureLines: [String]
    public let commonPhrases: [String]
    public let transitionPhrases: [String]
    
    // MARK: - Punctuation Style
    
    public let exclamationCount: Int
    public let questionCount: Int
    public let exclamationRatio: Double
    public let questionRatio: Double
    public let usesEmojis: Bool
    
    public init(
        emailID: UUID,
        extractedAt: Date = Date(),
        averageSentenceLength: Double = 0,
        sentenceCount: Int = 0,
        sentenceLengthDistribution: [Int] = [],
        averageWordLength: Double = 0,
        wordCount: Int = 0,
        uniqueWordCount: Int = 0,
        typeTokenRatio: Double = 0,
        contractionCount: Int = 0,
        contractionRatio: Double = 0,
        formalWordCount: Int = 0,
        informalWordCount: Int = 0,
        slangWords: [String] = [],
        paragraphCount: Int = 0,
        averageParagraphLength: Double = 0,
        hasGreeting: Bool = false,
        hasClosing: Bool = false,
        hasSignature: Bool = false,
        usesBulletPoints: Bool = false,
        greetingPattern: String? = nil,
        closingPattern: String? = nil,
        signatureLines: [String] = [],
        commonPhrases: [String] = [],
        transitionPhrases: [String] = [],
        exclamationCount: Int = 0,
        questionCount: Int = 0,
        exclamationRatio: Double = 0,
        questionRatio: Double = 0,
        usesEmojis: Bool = false
    ) {
        self.emailID = emailID
        self.extractedAt = extractedAt
        self.averageSentenceLength = averageSentenceLength
        self.sentenceCount = sentenceCount
        self.sentenceLengthDistribution = sentenceLengthDistribution
        self.averageWordLength = averageWordLength
        self.wordCount = wordCount
        self.uniqueWordCount = uniqueWordCount
        self.typeTokenRatio = typeTokenRatio
        self.contractionCount = contractionCount
        self.contractionRatio = contractionRatio
        self.formalWordCount = formalWordCount
        self.informalWordCount = informalWordCount
        self.slangWords = slangWords
        self.paragraphCount = paragraphCount
        self.averageParagraphLength = averageParagraphLength
        self.hasGreeting = hasGreeting
        self.hasClosing = hasClosing
        self.hasSignature = hasSignature
        self.usesBulletPoints = usesBulletPoints
        self.greetingPattern = greetingPattern
        self.closingPattern = closingPattern
        self.signatureLines = signatureLines
        self.commonPhrases = commonPhrases
        self.transitionPhrases = transitionPhrases
        self.exclamationCount = exclamationCount
        self.questionCount = questionCount
        self.exclamationRatio = exclamationRatio
        self.questionRatio = questionRatio
        self.usesEmojis = usesEmojis
    }
}

// MARK: - Feature Extractor

/// Extracts linguistic and stylistic features from email text
public actor FeatureExtractor {
    
    // MARK: - Constants
    
    private let commonContractions = [
        "n't", "'re", "'ve", "'ll", "'d", "'m", "'s",
        "can't", "won't", "don't", "isn't", "aren't", "wasn't", "weren't",
        "haven't", "hasn't", "hadn't", "wouldn't", "shouldn't", "couldn't",
        "let's", "that's", "who's", "what's", "here's", "there's", "where's"
    ]
    
    private let formalWords = [
        "dear", "regards", "sincerely", "respectfully", "pursuant", "hereby",
        "henceforth", "notwithstanding", "furthermore", "moreover", "consequently",
        "therefore", "accordingly", "nevertheless", "nonetheless", "aforementioned"
    ]
    
    private let informalWords = [
        "hey", "hi", "bye", "yeah", "nah", "gonna", "wanna", "gotta",
        "kinda", "sorta", "dunno", "lemme", "gimme", "ya", "y'all"
    ]
    
    private let slangWords = [
        "lol", "omg", "btw", "imo", "imho", "fyi", "asap", "tbh",
        "lmao", "rofl", "wtf", "ftw", "ftl", "irl", "afaik", "brb",
        "thx", "pls", "np", "idk", "smh", "tldr", "fomo", "lit",
        "cool", "awesome", "amazing", "terrible", "horrible", "fantastic"
    ]
    
    private let transitionPhrases = [
        "however", "therefore", "furthermore", "moreover", "consequently",
        "nevertheless", "meanwhile", "subsequently", "additionally",
        "in addition", "on the other hand", "in contrast", "for example",
        "for instance", "in conclusion", "to summarize", "as a result",
        "because of this", "due to", "in spite of", "even though"
    ]
    
    private let greetingPatterns = [
        "^\\s*(?:dear\\s+)?[a-z]+[,.]?",
        "^\\s*hi\\s+[a-z]+[,.]?",
        "^\\s*hello\\s+[a-z]+[,.]?",
        "^\\s*hey\\s+[a-z]+[,.]?",
        "^\\s*(?:good\\s+)?(?:morning|afternoon|evening)[,.]?",
        "^\\s*(?:hi|hello|hey)\\s*(?:there)?[,.]?",
        "^\\s*to\\s+whom\\s+it\\s+may\\s+concern[,.]?",
        "^\\s*greetings[,.]?"
    ]
    
    private let closingPatterns = [
        "(?:best|warm|kind)?\\s*regards[,.]?",
        "sincerely[,.]?",
        "thank\\s*(?:you|s)?[,.]?",
        "thanks[,.]?",
        "cheers[,.]?",
        "take\\s*care[,.]?",
        "have\\s*a\\s*(?:great|good|wonderful)\\s*(?:day|week|weekend)[,.]?",
        "talk\\s*to\\s*you\\s*(?:soon|later)[,.]?",
        "ttyl[,.]?",
        "looking\\s*forward\\s*to[,.]?"
    ]
    
    private let signatureIndicators = [
        "^[-=_]{2,}$",
        "^[a-z]+\\s+[a-z]+$",
        "^[a-z]+\\.\\s+[a-z]+$",
        "\\b(?:manager|director|ceo|cto|vp|president)\\b",
        "\\b(?:engineer|developer|designer|analyst)\\b",
        "@",
        "\\b(?:phone|tel|mobile)\\b",
        "\\b(?:linkedin|twitter|github)\\b"
    ]
    
    // MARK: - Properties
    
    private var phraseFrequency: [String: Int] = [:]
    private var ngramSize: Int
    
    // MARK: - Initialization
    
    public init(ngramSize: Int = 3) {
        self.ngramSize = ngramSize
    }
    
    // MARK: - Feature Extraction
    
    /// Extract features from an email
    public func extractFeatures(from email: Email) -> ExtractedFeatures {
        let text = email.bodyPlain ?? email.preview
        
        guard !text.isEmpty else {
            return ExtractedFeatures(emailID: email.id)
        }
        
        let normalizedText = normalizeText(text)
        let paragraphs = extractParagraphs(from: normalizedText)
        let sentences = extractSentences(from: normalizedText)
        let words = extractWords(from: normalizedText)
        
        return ExtractedFeatures(
            emailID: email.id,
            extractedAt: Date(),
            averageSentenceLength: calculateAverageSentenceLength(sentences: sentences),
            sentenceCount: sentences.count,
            sentenceLengthDistribution: calculateSentenceLengthDistribution(sentences: sentences),
            averageWordLength: calculateAverageWordLength(words: words),
            wordCount: words.count,
            uniqueWordCount: Set(words).count,
            typeTokenRatio: calculateTypeTokenRatio(words: words),
            contractionCount: countContractions(in: words),
            contractionRatio: calculateContractionRatio(words: words),
            formalWordCount: countFormalWords(in: words),
            informalWordCount: countInformalWords(in: words),
            slangWords: extractSlangWords(from: words),
            paragraphCount: paragraphs.count,
            averageParagraphLength: calculateAverageParagraphLength(paragraphs: paragraphs),
            hasGreeting: detectGreeting(in: normalizedText),
            hasClosing: detectClosing(in: normalizedText),
            hasSignature: detectSignature(in: paragraphs),
            usesBulletPoints: detectBulletPoints(in: normalizedText),
            greetingPattern: extractGreetingPattern(from: normalizedText),
            closingPattern: extractClosingPattern(from: normalizedText),
            signatureLines: extractSignatureLines(from: paragraphs),
            commonPhrases: extractCommonPhrases(from: sentences),
            transitionPhrases: extractTransitionPhrases(from: normalizedText),
            exclamationCount: countExclamations(in: normalizedText),
            questionCount: countQuestions(in: normalizedText),
            exclamationRatio: calculateExclamationRatio(text: normalizedText, sentenceCount: sentences.count),
            questionRatio: calculateQuestionRatio(text: normalizedText, sentenceCount: sentences.count),
            usesEmojis: detectEmojis(in: normalizedText)
        )
    }
    
    // MARK: - Text Normalization
    
    private func normalizeText(_ text: String) -> String {
        // Normalize whitespace and line endings
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        // Remove excessive whitespace
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Paragraph Extraction
    
    private func extractParagraphs(from text: String) -> [String] {
        return text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Sentence Extraction
    
    private func extractSentences(from text: String) -> [String] {
        // Split on sentence-ending punctuation followed by whitespace or newline
        let pattern = "[.!?]+\\s+"
        let sentences = text
            .components(separatedBy: .init(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return sentences
    }
    
    // MARK: - Word Extraction
    
    private func extractWords(from text: String) -> [String] {
        let lowercaseText = text.lowercased()
        let wordPattern = "\\b[a-z']+\\b"
        
        do {
            let regex = try NSRegularExpression(pattern: wordPattern, options: [])
            let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
            let matches = regex.matches(in: lowercaseText, options: [], range: range)
            
            return matches.compactMap { match in
                guard let range = Range(match.range, in: lowercaseText) else { return nil }
                return String(lowercaseText[range])
            }
        } catch {
            // Fallback: simple split
            return lowercaseText
                .components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                .filter { !$0.isEmpty }
        }
    }
    
    // MARK: - Sentence Metrics
    
    private func calculateAverageSentenceLength(sentences: [String]) -> Double {
        guard !sentences.isEmpty else { return 0 }
        
        let totalWordCount = sentences.reduce(0) { count, sentence in
            return count + extractWords(from: sentence).count
        }
        
        return Double(totalWordCount) / Double(sentences.count)
    }
    
    private func calculateSentenceLengthDistribution(sentences: [String]) -> [Int] {
        return sentences.map { extractWords(from: $0).count }
    }
    
    // MARK: - Word Metrics
    
    private func calculateAverageWordLength(words: [String]) -> Double {
        guard !words.isEmpty else { return 0 }
        
        let totalLength = words.reduce(0) { $0 + $1.count }
        return Double(totalLength) / Double(words.count)
    }
    
    private func calculateTypeTokenRatio(words: [String]) -> Double {
        guard !words.isEmpty else { return 0 }
        
        let uniqueWords = Set(words)
        return Double(uniqueWords.count) / Double(words.count)
    }
    
    // MARK: - Formality Markers
    
    private func countContractions(in words: [String]) -> Int {
        return words.filter { word in
            commonContractions.contains(word.lowercased()) || word.contains("'")
        }.count
    }
    
    private func calculateContractionRatio(words: [String]) -> Double {
        guard !words.isEmpty else { return 0 }
        return Double(countContractions(in: words)) / Double(words.count)
    }
    
    private func countFormalWords(in words: [String]) -> Int {
        return words.filter { formalWords.contains($0) }.count
    }
    
    private func countInformalWords(in words: [String]) -> Int {
        return words.filter { informalWords.contains($0) }.count
    }
    
    private func extractSlangWords(from words: [String]) -> [String] {
        return Array(Set(words.filter { slangWords.contains($0) }))
    }
    
    // MARK: - Structure Detection
    
    private func calculateAverageParagraphLength(paragraphs: [String]) -> Double {
        guard !paragraphs.isEmpty else { return 0 }
        
        let totalSentences = paragraphs.reduce(0) { count, paragraph in
            return count + extractSentences(from: paragraph).count
        }
        
        return Double(totalSentences) / Double(paragraphs.count)
    }
    
    private func detectGreeting(in text: String) -> Bool {
        let firstLine = text.components(separatedBy: .newlines).first?.lowercased() ?? ""
        
        for pattern in greetingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(firstLine.startIndex..., in: firstLine)
                if regex.firstMatch(in: firstLine, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func detectClosing(in text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let lastLines = Array(lines.suffix(5)).joined(separator: " ").lowercased()
        
        for pattern in closingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lastLines.startIndex..., in: lastLines)
                if regex.firstMatch(in: lastLines, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func detectSignature(in paragraphs: [String]) -> Bool {
        guard !paragraphs.isEmpty else { return false }
        
        let lastParagraph = paragraphs.last?.lowercased() ?? ""
        
        for pattern in signatureIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lastParagraph.startIndex..., in: lastParagraph)
                if regex.firstMatch(in: lastParagraph, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        // Check for separator line followed by short text (typical signature)
        if paragraphs.count >= 2 {
            let secondLast = paragraphs[paragraphs.count - 2]
            let separatorPattern = "^[-=_]{2,}$"
            if let regex = try? NSRegularExpression(pattern: separatorPattern),
               let _ = regex.firstMatch(in: secondLast, options: [], range: NSRange(secondLast.startIndex..., in: secondLast)) {
                return true
            }
        }
        
        return false
    }
    
    private func detectBulletPoints(in text: String) -> Bool {
        let bulletPattern = "^[\\s]*[•\\-\\*\\d+\\.]\\s+"
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if let regex = try? NSRegularExpression(pattern: bulletPattern, options: []),
               let _ = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Pattern Extraction
    
    private func extractGreetingPattern(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) else { return nil }
        
        for pattern in greetingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(firstLine.startIndex..., in: firstLine)
                if let match = regex.firstMatch(in: firstLine, options: [], range: range) {
                    if let matchRange = Range(match.range, in: firstLine) {
                        return String(firstLine[matchRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractClosingPattern(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let candidateLines = Array(lines.suffix(5))
        
        for line in candidateLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            for pattern in closingPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(trimmed.startIndex..., in: trimmed)
                    if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                        if let matchRange = Range(match.range, in: line) {
                            return String(line[matchRange])
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractSignatureLines(from paragraphs: [String]) -> [String] {
        guard paragraphs.count >= 2 else { return [] }
        
        var signatureLines: [String] = []
        
        // Check for separator line
        let secondLast = paragraphs[paragraphs.count - 2]
        let separatorPattern = "^[-=_]{2,}$"
        if let regex = try? NSRegularExpression(pattern: separatorPattern),
           let _ = regex.firstMatch(in: secondLast, options: [], range: NSRange(secondLast.startIndex..., in: secondLast)) {
            signatureLines = [paragraphs.last!]
        }
        
        // Also check last paragraph for signature indicators
        let lastParagraph = paragraphs.last?.lowercased() ?? ""
        for pattern in signatureIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lastParagraph.startIndex..., in: lastParagraph)
                if regex.firstMatch(in: lastParagraph, options: [], range: range) != nil {
                    if signatureLines.isEmpty {
                        signatureLines = [paragraphs.last!]
                    }
                }
            }
        }
        
        return signatureLines
    }
    
    private func extractCommonPhrases(from sentences: [String]) -> [String] {
        var phraseCounts: [String: Int] = [:]
        
        for sentence in sentences {
            let words = extractWords(from: sentence)
            
            // Extract n-grams (2-grams and 3-grams)
            for n in 2...min(3, words.count) {
                for i in 0...(words.count - n) {
                    let ngram = words[i..<(i+n)].joined(separator: " ")
                    phraseCounts[ngram, default: 0] += 1
                }
            }
        }
        
        // Filter for phrases that appear multiple times
        let commonPhrases = phraseCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        return Array(commonPhrases)
    }
    
    private func extractTransitionPhrases(from text: String) -> [String] {
        let lowercaseText = text.lowercased()
        return transitionPhrases.filter { lowercaseText.contains($0) }
    }
    
    // MARK: - Punctuation Analysis
    
    private func countExclamations(in text: String) -> Int {
        return text.filter { $0 == "!" }.count
    }
    
    private func countQuestions(in text: String) -> Int {
        return text.filter { $0 == "?" }.count
    }
    
    private func calculateExclamationRatio(text: String, sentenceCount: Int) -> Double {
        guard sentenceCount > 0 else { return 0 }
        return Double(countExclamations(in: text)) / Double(sentenceCount)
    }
    
    private func calculateQuestionRatio(text: String, sentenceCount: Int) -> Double {
        guard sentenceCount > 0 else { return 0 }
        return Double(countQuestions(in: text)) / Double(sentenceCount)
    }
    
    private func detectEmojis(in text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji {
                return true
            }
        }
        return false
    }
}

// MARK: - UnicodeScalar Emoji Detection

private extension UnicodeScalar {
    /// Check if this scalar is an emoji
    var isEmoji: Bool {
        // Check if scalar is in emoji ranges
        return self.value >= 0x1F600 && self.value <= 0x1F64F  // Emoticons
            || self.value >= 0x1F300 && self.value <= 0x1F5FF  // Misc Symbols and Pictographs
            || self.value >= 0x1F680 && self.value <= 0x1F6FF  // Transport and Map
            || self.value >= 0x2600 && self.value <= 0x26FF    // Misc symbols
            || self.value >= 0x2700 && self.value <= 0x27BF    // Dingbats
            || self.value >= 0x1F900 && self.value <= 0x1F9FF  // Supplemental Symbols
    }
}
