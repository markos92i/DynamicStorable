
import Foundation
import Testing
@testable import DynamicStorable

@Suite
struct StorableTest {
    struct CodableTest: Codable {
        var test: String
    }
    
    init() {
        let urls = try? FileManager.default.contentsOfDirectory(at: .documentsDirectory,
                                                                includingPropertiesForKeys: nil,
                                                                options: .skipsHiddenFiles)
        for url in urls ?? [] {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    @Test func optionalCodable() async throws {
        @Storable("test.value.optional.codable") var value: CodableTest?

        value = .init(test: "Hello World!")
        #expect(value?.test == "Hello World!")
        
        value = nil
        #expect(value == nil)
    }
    
    @Test func defaultCodable() async throws {
        @Storable("test.value.default.codable") var value: CodableTest = .init(test: "Hello!")
        #expect(value.test == "Hello!")
        value = .init(test: "Hello World!")
        #expect(value.test == "Hello World!")
    }
}
