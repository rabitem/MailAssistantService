import Foundation
import PluginAPI

// MARK: - Prompt Context

public struct PromptContext {
    public let email: Email
    public let threadContext: [Email]
    public let senderContact: Contact?
    public let userWritingStyle: WritingStyle?
    public let ragExamples: [RAGExample]
    public let tone: ResponseTone
    public let length: ResponseLength
    public let purpose: ResponsePurpose
    
    public init(
        email: Email,
        threadContext: [Email] = [],
        senderContact: Contact? = nil,
        userWritingStyle: WritingStyle? = nil,
        ragExamples: [RAGExample] = [],
        tone: ResponseTone = .auto,
        length: ResponseLength = .medium,
        purpose: ResponsePurpose = .reply
    ) {
        self.email = email
        self.threadContext = threadContext
        self.senderContact = senderContact
        self.userWritingStyle = userWritingStyle
        self.ragExamples = ragExamples
        self.tone = tone
        self.length = length
        self.purpose = purpose
    }
}

// MARK: - Response Configuration

public enum ResponseTone: String, CaseIterable, Identifiable {
    case auto = "auto"
    case formal = "formal"
    case casual = "casual"
    case friendly = "friendly"
    case professional = "professional"
    case assertive = "assertive"
    case diplomatic = "diplomatic"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        case .assertive: return "Assertive"
        case .diplomatic: return "Diplomatic"
        }
    }
}

public enum ResponseLength: String, CaseIterable, Identifiable {
    case short = "short"
    case medium = "medium"
    case long = "long"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .short: return "Brief"
        case .medium: return "Standard"
        case .long: return "Detailed"
        }
    }
    
    public var wordCount: ClosedRange<Int> {
        switch self {
        case .short: return 30...80
        case .medium: return 80...200
        case .long: return 200...400
        }
    }
}

public enum ResponsePurpose: String, CaseIterable {
    case reply = "reply"
    case followUp = "follow_up"
    case introduction = "introduction"
    case decline = "decline"
    case accept = "accept"
    case request = "request"
    case apology = "apology"
    case reminder = "reminder"
}

// MARK: - RAG Example

public struct RAGExample: Identifiable, Equatable {
    public let id: String
    public let incomingEmail: String
    public let userResponse: String
    public let similarity: Double
    public let date: Date
    
    public init(
        id: String = UUID().uuidString,
        incomingEmail: String,
        userResponse: String,
        similarity: Double,
        date: Date
    ) {
        self.id = id
        self.incomingEmail = incomingEmail
        self.userResponse = userResponse
        self.similarity = similarity
        self.date = date
    }
}

// MARK: - Prompt Templates

public struct PromptTemplates {
    
    // MARK: - System Prompts
    
    public static let baseSystemPrompt = """
    You are an intelligent email writing assistant. Your task is to help compose email responses that are natural, contextually appropriate, and match the user's personal writing style.
    
    Guidelines:
    - Write responses that sound authentic and human
    - Match the tone and formality of the incoming email
    - Be concise but thorough
    - Never invent information not provided in context
    - Use proper email etiquette (greetings, closings)
    """
    
    public static func styleAwareSystemPrompt(style: WritingStyle?) -> String {
        guard let style = style else {
            return baseSystemPrompt
        }
        
        var prompt = baseSystemPrompt + "\n\n"
        prompt += "=== USER WRITING STYLE PROFILE ===\n"
        prompt += "Formality Level: \(formatScore(style.formalityScore))\n"
        prompt += "Friendliness: \(formatScore(style.friendlinessScore))\n"
        prompt += "Brevity Preference: \(formatScore(style.brevityScore))\n"
        prompt += "Enthusiasm: \(formatScore(style.enthusiasmScore))\n"
        
        if let avgSentenceLength = style.avgSentenceLength {
            prompt += "Average Sentence Length: \(Int(avgSentenceLength)) words\n"
        }
        
        if !style.commonPhrases.isEmpty {
            prompt += "\nCommon Phrases Used:\n"
            for phrase in style.commonPhrases.prefix(5) {
                prompt += "- \"\(phrase)\"\n"
            }
        }
        
        if !style.greetingPatterns.isEmpty {
            prompt += "\nTypical Greetings:\n"
            for greeting in style.greetingPatterns.prefix(3) {
                prompt += "- \(greeting)\n"
            }
        }
        
        if !style.closingPatterns.isEmpty {
            prompt += "\nTypical Closings:\n"
            for closing in style.closingPatterns.prefix(3) {
                prompt += "- \(closing)\n"
            }
        }
        
        prompt += "\nPlease adapt your response to match this writing style as closely as possible."
        
        return prompt
    }
    
    // MARK: - Task Instructions
    
    public static func taskInstructions(
        tone: ResponseTone,
        length: ResponseLength,
        purpose: ResponsePurpose
    ) -> String {
        var instructions = "\n=== RESPONSE REQUIREMENTS ===\n"
        
        // Tone instructions
        switch tone {
        case .auto:
            instructions += "- Match the tone of the incoming email\n"
        case .formal:
            instructions += "- Use formal language and professional etiquette\n"
            instructions += "- Avoid contractions and colloquialisms\n"
            instructions += "- Use complete sentences and proper grammar\n"
        case .casual:
            instructions += "- Use casual, conversational language\n"
            instructions += "- Contractions are acceptable\n"
            instructions += "- Keep it friendly and approachable\n"
        case .friendly:
            instructions += "- Warm and personable tone\n"
            instructions += "- Show genuine interest and engagement\n"
            instructions += "- Use positive, encouraging language\n"
        case .professional:
            instructions += "- Professional but not overly formal\n"
            instructions += "- Clear and direct communication\n"
            instructions += "- Balance friendliness with professionalism\n"
        case .assertive:
            instructions += "- Clear, direct, and confident tone\n"
            instructions += "- State positions firmly but respectfully\n"
            instructions += "- Avoid hedging or overly apologetic language\n"
        case .diplomatic:
            instructions += "- Tactful and considerate tone\n"
            instructions += "- Soften difficult messages appropriately\n"
            instructions += "- Show empathy and understanding\n"
        }
        
        // Length instructions
        instructions += "\n"
        switch length {
        case .short:
            instructions += "- Keep the response brief and to the point\n"
            instructions += "- Aim for \(length.wordCount.lowerBound)-\(length.wordCount.upperBound) words\n"
            instructions += "- Prioritize essential information only\n"
        case .medium:
            instructions += "- Provide a balanced, standard-length response\n"
            instructions += "- Aim for \(length.wordCount.lowerBound)-\(length.wordCount.upperBound) words\n"
            instructions += "- Include necessary details without being verbose\n"
        case .long:
            instructions += "- Provide a detailed, comprehensive response\n"
            instructions += "- Aim for \(length.wordCount.lowerBound)-\(length.wordCount.upperBound) words\n"
            instructions += "- Include all relevant details and context\n"
        }
        
        // Purpose-specific instructions
        instructions += "\n"
        switch purpose {
        case .reply:
            instructions += "- Address all points raised in the incoming email\n"
            instructions += "- Answer any questions asked\n"
        case .followUp:
            instructions += "- Reference previous communication\n"
            instructions += "- Provide requested updates or information\n"
        case .introduction:
            instructions += "- Briefly introduce yourself and context\n"
            instructions += "- Establish relevance and connection\n"
        case .decline:
            instructions += "- Decline politely and clearly\n"
            instructions += "- Provide a brief reason if appropriate\n"
            instructions += "- Leave the door open for future opportunities\n"
        case .accept:
            instructions += "- Express enthusiasm and gratitude\n"
            instructions += "- Confirm details and next steps\n"
        case .request:
            instructions += "- Clearly state what you're asking for\n"
            instructions += "- Provide context and justification\n"
            instructions += "- Make it easy to say yes\n"
        case .apology:
            instructions += "- Acknowledge the issue sincerely\n"
            instructions += "- Take responsibility appropriately\n"
            instructions += "- Offer resolution or amends\n"
        case .reminder:
            instructions += "- Reference the original commitment\n"
            instructions += "- Be polite but clear about urgency\n"
        }
        
        return instructions
    }
    
    // MARK: - Formatting
    
    private static func formatScore(_ score: Double) -> String {
        if score >= 0.8 { return "Very High (\(Int(score * 100))%)" }
        if score >= 0.6 { return "High (\(Int(score * 100))%)" }
        if score >= 0.4 { return "Moderate (\(Int(score * 100))%)" }
        if score >= 0.2 { return "Low (\(Int(score * 100))%)" }
        return "Very Low (\(Int(score * 100))%)"
    }
}

// MARK: - PromptEngine

public actor PromptEngine {
    
    // MARK: - Singleton
    
    public static let shared = PromptEngine()
    
    // MARK: - Properties
    
    private var logger = Logger(subsystem: "kimimail.ai", category: "PromptEngine")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Prompt Building
    
    /// Builds a complete prompt for email response generation
    public func buildResponsePrompt(context: PromptContext) -> String {
        var prompt = ""
        
        // 1. Add system context (writing style, user preferences)
        prompt += buildSystemContext(style: context.userWritingStyle)
        prompt += "\n\n"
        
        // 2. Add RAG examples (similar past responses)
        if !context.ragExamples.isEmpty {
            prompt += buildRAGContext(examples: context.ragExamples)
            prompt += "\n\n"
        }
        
        // 3. Add thread context if available
        if !context.threadContext.isEmpty {
            prompt += buildThreadContext(emails: context.threadContext)
            prompt += "\n\n"
        }
        
        // 4. Add sender/contact context
        if let contact = context.senderContact {
            prompt += buildContactContext(contact: contact)
            prompt += "\n\n"
        }
        
        // 5. Add the email to respond to
        prompt += buildEmailContext(email: context.email)
        prompt += "\n\n"
        
        // 6. Add task instructions
        prompt += PromptTemplates.taskInstructions(
            tone: context.tone,
            length: context.length,
            purpose: context.purpose
        )
        
        // 7. Final instruction
        prompt += "\n\nPlease compose a response to the email above."
        
        logger.debug("Built prompt with \(prompt.count) characters")
        
        return prompt
    }
    
    /// Builds system prompt with writing style context
    public func buildSystemPrompt(style: WritingStyle?) -> String {
        return PromptTemplates.styleAwareSystemPrompt(style: style)
    }
    
    // MARK: - Component Builders
    
    private func buildSystemContext(style: WritingStyle?) -> String {
        return PromptTemplates.styleAwareSystemPrompt(style: style)
    }
    
    private func buildRAGContext(examples: [RAGExample]) -> String {
        var context = "=== SIMILAR PAST EMAILS FOR REFERENCE ===\n"
        context += "The following are examples of how you've responded to similar emails in the past. "
        context += "Use these as inspiration for style and tone, but don't copy them directly.\n\n"
        
        for (index, example) in examples.enumerated() {
            context += "--- Example \(index + 1) (Similarity: \(Int(example.similarity * 100))%) ---\n"
            context += "Incoming Email:\n\(example.incomingEmail.prefix(500))\n\n"
            context += "Your Response:\n\(example.userResponse)\n\n"
        }
        
        return context
    }
    
    private func buildThreadContext(emails: [Email]) -> String {
        var context = "=== EMAIL THREAD CONTEXT ===\n"
        context += "This email is part of an ongoing conversation. Here are the previous messages:\n\n"
        
        for (index, email) in emails.sorted(by: { $0.sentDate ?? Date.distantPast < $1.sentDate ?? Date.distantPast }).enumerated() {
            context += "--- Message \(index + 1) ---\n"
            context += "From: \(email.senderName ?? email.senderEmail)\n"
            context += "Subject: \(email.subject ?? "(no subject)")\n"
            if let date = email.sentDate {
                context += "Date: \(formatDate(date))\n"
            }
            context += "\n\(email.bodyPlain?.prefix(300) ?? "(no content)")\n\n"
        }
        
        return context
    }
    
    private func buildContactContext(contact: Contact) -> String {
        var context = "=== SENDER INFORMATION ===\n"
        context += "Name: \(contact.name ?? contact.email)\n"
        
        if let company = contact.company {
            context += "Company: \(company)\n"
        }
        
        if let role = contact.role {
            context += "Role: \(role)\n"
        }
        
        context += "Total emails received: \(contact.emailCountReceived)\n"
        context += "Total emails sent: \(contact.emailCountSent)\n"
        
        if let lastContacted = contact.lastContacted {
            context += "Last contacted: \(formatDate(lastContacted))\n"
        }
        
        if let relationshipScore = contact.relationshipScore {
            let strength = relationshipScore > 0.7 ? "strong" : relationshipScore > 0.4 ? "moderate" : "new"
            context += "Relationship strength: \(strength)\n"
        }
        
        return context
    }
    
    private func buildEmailContext(email: Email) -> String {
        var context = "=== EMAIL TO RESPOND TO ===\n"
        context += "From: \(email.senderName ?? email.senderEmail)\n"
        context += "Subject: \(email.subject ?? "(no subject)")\n"
        
        if let date = email.sentDate {
            context += "Date: \(formatDate(date))\n"
        }
        
        if let to = email.recipientsTo, !to.isEmpty {
            context += "To: \(to.joined(separator: ", "))\n"
        }
        
        context += "\n--- Email Body ---\n"
        context += email.bodyPlain ?? email.bodyHtml?.stripHTML() ?? "(no content)"
        
        return context
    }
    
    // MARK: - Specialized Prompts
    
    /// Builds a prompt for style analysis
    public func buildStyleAnalysisPrompt(emails: [Email]) -> String {
        let emailTexts = emails.map { email in
            """
            Subject: \(email.subject ?? "(no subject)")
            Body: \(email.bodyPlain?.prefix(1000) ?? "(no content)")
            ---
            """
        }.joined(separator: "\n\n")
        
        return """
        Analyze the following sent emails to extract the author's writing style characteristics.
        
        Provide analysis in this format:
        
        Formality (0.0-1.0):
        Friendliness (0.0-1.0):
        Brevity (0.0-1.0):
        Enthusiasm (0.0-1.0):
        Average sentence length:
        Common phrases:
        Typical greetings:
        Typical closings:
        
        Emails to analyze:
        \(emailTexts)
        """
    }
    
    /// Builds a prompt for email summarization
    public func buildSummarizationPrompt(email: Email, maxLength: Int = 100) -> String {
        return """
        Summarize the following email in \(maxLength) characters or less. 
        Capture the key points and any action items.
        
        Subject: \(email.subject ?? "(no subject)")
        From: \(email.senderName ?? email.senderEmail)
        
        \(email.bodyPlain?.prefix(2000) ?? "(no content)")
        """
    }
    
    /// Builds a prompt for intent detection
    public func buildIntentDetectionPrompt(email: Email) -> String {
        return """
        Analyze the following email and identify the primary intent and any action items.
        
        Possible intents: question, request, information_share, follow_up_needed, urgent, meeting_scheduling, deadline_mentioned, appreciation, complaint, other
        
        Respond in JSON format:
        {
            "primary_intent": "...",
            "confidence": 0.0-1.0,
            "action_items": ["..."],
            "urgency": "low|medium|high",
            "sentiment": "positive|neutral|negative"
        }
        
        Email:
        Subject: \(email.subject ?? "(no subject)")
        From: \(email.senderName ?? email.senderEmail)
        
        \(email.bodyPlain?.prefix(1500) ?? "(no content)")
        """
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - String Extensions

private extension String {
    func stripHTML() -> String {
        // Simple HTML tag removal - in production, use a proper HTML parser
        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return self
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
