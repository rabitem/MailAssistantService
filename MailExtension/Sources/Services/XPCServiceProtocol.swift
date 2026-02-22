//
//  XPCServiceProtocol.swift
//  MailExtension
//

import Foundation

/// Protocol for communication with the Mail Assistant XPC Service
@objc protocol XPCServiceProtocol {
    /// Generate response suggestions for an email
    func generateResponses(
        request: GenerationRequest,
        completion: @escaping (Result<[GeneratedResponse], Error>) -> Void
    )
    
    /// Analyze the tone of an email
    func analyzeTone(
        content: EmailContent,
        completion: @escaping (Result<ToneAnalysis, Error>) -> Void
    )
    
    /// Summarize an email thread
    func summarizeThread(
        messages: [EmailContent.ThreadMessage],
        completion: @escaping (Result<String, Error>) -> Void
    )
    
    /// Cancel ongoing generation
    func cancelGeneration()
    
    /// Check service availability
    func ping(completion: @escaping (Bool) -> Void)
}

/// Tone analysis result
struct ToneAnalysis: Codable {
    let overallTone: ResponseTone
    let confidence: Double
    let formalityScore: Double
    let sentimentScore: Double
    let suggestions: [ToneSuggestion]
    
    struct ToneSuggestion: Codable {
        let type: SuggestionType
        let description: String
        let severity: Severity
        
        enum SuggestionType: String, Codable {
            case tooFormal
            case tooCasual
            case ambiguous
            case potentiallyOffensive
            case missingGreeting
            case missingClosing
        }
        
        enum Severity: String, Codable {
            case info
            case warning
            case critical
        }
    }
}

/// XPC Service connection manager
class XPCServiceConnection: ObservableObject {
    static let shared = XPCServiceConnection()
    
    @Published var isConnected: Bool = false
    @Published var lastError: Error?
    
    private var connection: NSXPCConnection?
    private var service: XPCServiceProtocol?
    
    private init() {
        connect()
    }
    
    func connect() {
        connection = NSXPCConnection(serviceName: "de.rabitem.MailAssistant.MailAssistantService")
        connection?.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        
        connection?.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.service = nil
            }
        }
        
        connection?.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        connection?.resume()
        
        service = connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error
                self?.isConnected = false
            }
        } as? XPCServiceProtocol
        
        // Verify connection
        ping()
    }
    
    func disconnect() {
        connection?.invalidate()
        connection = nil
        service = nil
        isConnected = false
    }
    
    func ping() {
        service?.ping { [weak self] success in
            DispatchQueue.main.async {
                self?.isConnected = success
            }
        }
    }
    
    func getService() -> XPCServiceProtocol? {
        if !isConnected {
            connect()
        }
        return service
    }
}

/// Mock service for development/testing
class MockXPCService: XPCServiceProtocol {
    static let shared = MockXPCService()
    
    func generateResponses(
        request: GenerationRequest,
        completion: @escaping (Result<[GeneratedResponse], Error>) -> Void
    ) {
        // Simulate network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            let mockResponses = [
                GeneratedResponse(
                    text: self.mockResponseText(for: request.tone, length: request.length, variant: 1),
                    tone: request.tone,
                    length: request.length,
                    confidence: 0.95
                ),
                GeneratedResponse(
                    text: self.mockResponseText(for: request.tone, length: request.length, variant: 2),
                    tone: request.tone,
                    length: request.length,
                    confidence: 0.88
                ),
                GeneratedResponse(
                    text: self.mockResponseText(for: request.tone, length: request.length, variant: 3),
                    tone: request.tone,
                    length: request.length,
                    confidence: 0.82
                )
            ]
            completion(.success(mockResponses))
        }
    }
    
    func analyzeTone(content: EmailContent, completion: @escaping (Result<ToneAnalysis, Error>) -> Void) {
        let analysis = ToneAnalysis(
            overallTone: .professional,
            confidence: 0.87,
            formalityScore: 0.75,
            sentimentScore: 0.6,
            suggestions: []
        )
        completion(.success(analysis))
    }
    
    func summarizeThread(messages: [EmailContent.ThreadMessage], completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success("This is a mock summary of the email thread."))
    }
    
    func cancelGeneration() {
        // No-op for mock
    }
    
    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    private func mockResponseText(for tone: ResponseTone, length: ResponseLength, variant: Int) -> String {
        let greetings = [
            "Hi there,",
            "Hello,",
            "Dear colleague,"
        ]
        let greeting = greetings[variant % greetings.count]
        
        let bodies: [String]
        switch length {
        case .brief:
            bodies = [
                "Thanks for your email. I agree with your proposal and will review it by Friday.",
                "Got it. I'll follow up with the team and get back to you soon.",
                "Noted. Let me check on this and respond shortly."
            ]
        case .standard:
            bodies = [
                "Thank you for reaching out. I've reviewed your proposal and think it looks great. I'll need to run it by the team, but I expect we'll be able to move forward by the end of the week. Let me know if you have any questions in the meantime.",
                "I appreciate you sending this over. After reviewing the details, I'm on board with the plan. I'll coordinate with the relevant stakeholders and follow up with next steps by Friday. Please feel free to reach out if anything changes.",
                "Thanks for getting in touch. I've had a chance to look through everything, and I'm in agreement with your approach. I'll need to confirm a few details on my end, but I'll get back to you with a definitive answer soon."
            ]
        case .detailed:
            bodies = [
                "Thank you very much for sending this detailed proposal. I've taken the time to review all the materials you provided, and I'm impressed with the thoroughness of your work. The approach you've outlined aligns well with our objectives, and I believe it has strong potential for success.\n\nThat said, I want to make sure we consider this from all angles. I'll be discussing it with the leadership team in our meeting tomorrow morning, and I should have feedback for you by Friday afternoon. In the meantime, if there are any additional documents or context you think would be helpful, please don't hesitate to share them.\n\nI appreciate your patience, and I'm looking forward to working together on this.",
                "I wanted to thank you for reaching out with this comprehensive proposal. After carefully reviewing all the documentation and considering how it fits into our current initiatives, I'm quite positive about moving forward. The timeline you've proposed seems realistic, and the budget considerations align with our expectations.\n\nHowever, before I give final approval, I'd like to run this past a couple of key stakeholders who weren't included in the initial distribution. I'll be meeting with them over the next two days and will consolidate their feedback. You can expect to hear back from me by Friday with either a green light or specific questions that need addressing.\n\nPlease let me know if anything changes on your end in the meantime.",
                "Thank you for taking the time to put together such a thoughtful proposal. I've reviewed the entire package, including the supporting materials, and I find your recommendations to be well-researched and compelling. The strategic direction you've outlined makes sense given our current priorities.\n\nWhile I'm personally supportive of this approach, I do need to ensure we have full organizational alignment before proceeding. I'll be presenting this to the executive committee on Thursday, and based on that discussion, I'll provide you with detailed feedback and next steps by Friday EOD. If there are any additional points you'd like me to emphasize during that presentation, please send them my way.\n\nThanks again for your thorough work on this."
            ]
        }
        
        let body = bodies[variant % bodies.count]
        
        let closings: [String]
        switch tone {
        case .formal:
            closings = ["Best regards,", "Sincerely,", "Respectfully,"]
        case .casual:
            closings = ["Thanks,", "Cheers,", "Talk soon,"]
        case .friendly:
            closings = ["Best,", "Take care,", "Looking forward to hearing from you,"]
        case .professional:
            closings = ["Best regards,", "Regards,", "Thank you,"]
        case .empathetic:
            closings = ["With appreciation,", "Warmly,", "Thinking of you,"]
        }
        let closing = closings[variant % closings.count]
        
        return "\(greeting)\n\n\(body)\n\n\(closing)"
    }
}
