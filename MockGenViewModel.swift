import Foundation
import Combine

class MockGenViewModel: ObservableObject {
    @Published var protocolInput: String = ""
    @Published var generatedMock: String = ""
    @Published var moduleName: String = "YourModule"
    @Published var authorName: String = "Developer"
    @Published var appName: String = "YourApp"
    
    private let parser = MockGenParser()
    private let userDefaults = UserDefaults.standard
    
    private let moduleNameKey = "MockGen_ModuleName"
    private let authorNameKey = "MockGen_AuthorName"
    private let appNameKey = "MockGen_AppName"
    
    func loadSettings() {
        moduleName = userDefaults.string(forKey: moduleNameKey) ?? "YourModule"
        authorName = userDefaults.string(forKey: authorNameKey) ?? "Developer"
        appName = userDefaults.string(forKey: appNameKey) ?? "YourApp"
    }
    
    func saveSettings() {
        userDefaults.set(moduleName, forKey: moduleNameKey)
        userDefaults.set(authorName, forKey: authorNameKey)
        userDefaults.set(appName, forKey: appNameKey)
    }
    
    func generateMock() {
        guard !protocolInput.isEmpty else {
            generatedMock = ""
            return
        }
        
        // Парсим протокол
        guard let protocolDef = parser.parseProtocol(protocolInput) else {
            generatedMock = "Error: Could not parse protocol"
            return
        }
        
        // Генерируем мок
        let generator = MockGenCodeGenerator(
            protocolDef: protocolDef,
            authorName: authorName,
            appName: appName,
            moduleName: moduleName
        )
        
        let mockFile = generator.generateMock()
        generatedMock = mockFile.content
    }
}
