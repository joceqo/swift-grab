import Foundation
import CoreGraphics

public struct GrabPayload: Codable, Sendable {
    public struct GrabMetadata: Codable, Sendable {
        public var appBundleIdentifier: String?
        public var processIdentifier: Int32?
        public var windowTitle: String?
        public var viewType: String?
        public var accessibilityRole: String?
        public var accessibilitySubrole: String?
        public var accessibilityIdentifier: String?
        public var accessibilityTitle: String?
        public var accessibilityValue: String?
        public var accessibilityHelp: String?
        public var accessibilityURL: String?
        public var accessibilitySelectedText: String?
        public var elementDescription: String?
        public var viewHierarchy: [String]?
        public var timestamp: Date

        public init(
            appBundleIdentifier: String? = nil,
            processIdentifier: Int32? = nil,
            windowTitle: String? = nil,
            viewType: String? = nil,
            accessibilityRole: String? = nil,
            accessibilitySubrole: String? = nil,
            accessibilityIdentifier: String? = nil,
            accessibilityTitle: String? = nil,
            accessibilityValue: String? = nil,
            accessibilityHelp: String? = nil,
            accessibilityURL: String? = nil,
            accessibilitySelectedText: String? = nil,
            elementDescription: String? = nil,
            viewHierarchy: [String]? = nil,
            timestamp: Date = Date()
        ) {
            self.appBundleIdentifier = appBundleIdentifier
            self.processIdentifier = processIdentifier
            self.windowTitle = windowTitle
            self.viewType = viewType
            self.accessibilityRole = accessibilityRole
            self.accessibilitySubrole = accessibilitySubrole
            self.accessibilityIdentifier = accessibilityIdentifier
            self.accessibilityTitle = accessibilityTitle
            self.accessibilityValue = accessibilityValue
            self.accessibilityHelp = accessibilityHelp
            self.accessibilityURL = accessibilityURL
            self.accessibilitySelectedText = accessibilitySelectedText
            self.elementDescription = elementDescription
            self.viewHierarchy = viewHierarchy
            self.timestamp = timestamp
        }
    }

    public var mode: GrabMode
    public var screenFrame: CGRect
    public var cursorPoint: CGPoint
    public var userNote: String?
    public var metadata: GrabMetadata
    public var errors: [String]

    public init(
        mode: GrabMode,
        screenFrame: CGRect,
        cursorPoint: CGPoint,
        userNote: String? = nil,
        metadata: GrabMetadata,
        errors: [String] = []
    ) {
        self.mode = mode
        self.screenFrame = screenFrame
        self.cursorPoint = cursorPoint
        self.userNote = userNote
        self.metadata = metadata
        self.errors = errors
    }

    public func toJSON(prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

public enum GrabMode: String, Codable, Sendable {
    case appLocal
    case global
}
