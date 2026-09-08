import XCTest
import Combine
@testable import MockGen

class MockGenParserTests: XCTestCase {
    
    var parser: MockGenParser!
    
    override func setUp() {
        super.setUp()
        parser = MockGenParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Protocol Name Extraction
    
    func testParseProtocolNameSimple() {
        let input = """
        protocol MyRouter {
            func navigate()
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouter")
    }
    
    func testParseProtocolNameWithAnyObject() {
        let input = """
        protocol MyRouter: AnyObject {
            func navigate()
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouter")
    }
    
    func testParseProtocolNameEmpty() {
        let input = ""
        let result = parser.parseProtocol(input)
        XCTAssertNil(result)
    }
    
    func testParseProtocolNameWithComments() {
        let input = """
        // This is a protocol
        /// Documentation
        protocol MyRouter {
            func navigate()
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouter")
    }
    
    // MARK: - Property Parsing
    
    func testParsePropertySimple() {
        let input = """
        protocol MyRouter {
            var currentPage: String { get }
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.properties.count, 1)
        XCTAssertEqual(result?.properties.first?.name, "currentPage")
        XCTAssertEqual(result?.properties.first?.type, "String")
    }
    
    func testParseMultipleProperties() {
        let input = """
        protocol MyRouter {
            var currentPage: String { get }
            var isLoading: Bool { get }
            var userId: Int { get }
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.properties.count, 3)
        XCTAssertEqual(result?.properties[0].name, "currentPage")
        XCTAssertEqual(result?.properties[1].name, "isLoading")
        XCTAssertEqual(result?.properties[2].name, "userId")
    }
    
    func testParsePropertyComplexType() {
        let input = """
        protocol MyRouter {
            var delegate: UIViewControllerDelegate? { get }
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.properties.first?.type, "UIViewControllerDelegate?")
    }
    
    func testParsePropertyGenericType() {
        let input = """
        protocol MyRouter {
            var items: [String] { get }
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.properties.first?.type, "[String]")
    }
    
    func testParsePropertyDictionaryType() {
        let input = """
        protocol MyRouter {
            var config: [String: Any] { get }
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.properties.first?.type, "[String: Any]")
    }
    
    // MARK: - Method Parsing (Basic)
    
    func testParseMethodNoParameters() {
        let input = """
        protocol MyRouter {
            func navigate()
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.count, 1)
        XCTAssertEqual(result?.methods.first?.name, "navigate")
        XCTAssertEqual(result?.methods.first?.parameters.count, 0)
        XCTAssertEqual(result?.methods.first?.returnType, "Void")
    }
    
    func testParseMethodSingleParameter() {
        let input = """
        protocol MyRouter {
            func navigate(to page: String)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.count, 1)
        XCTAssertEqual(result?.methods.first?.parameters.first?.name, "page")
        XCTAssertEqual(result?.methods.first?.parameters.first?.type, "String")
    }
    
    func testParseMethodMultipleParameters() {
        let input = """
        protocol MyRouter {
            func navigate(to page: String, animated: Bool, completion: () -> Void)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.count, 3)
        XCTAssertEqual(result?.methods.first?.parameters[0].name, "page")
        XCTAssertEqual(result?.methods.first?.parameters[1].name, "animated")
        XCTAssertEqual(result?.methods.first?.parameters[2].name, "completion")
    }
    
    func testParseMethodWithReturnType() {
        let input = """
        protocol MyRouter {
            func fetchUser() -> User
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.returnType, "User")
    }
    
    func testParseMethodWithOptionalReturnType() {
        let input = """
        protocol MyRouter {
            func fetchUser() -> User?
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.returnType, "User?")
    }
    
    func testParseMethodWithArrayReturnType() {
        let input = """
        protocol MyRouter {
            func fetchUsers() -> [User]
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.returnType, "[User]")
    }
    
    // MARK: - Method Parsing (Async/Throws)
    
    func testParseMethodThrows() {
        let input = """
        protocol MyRouter {
            func navigate(to page: String) throws
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.methods.first?.isThrows ?? false)
        XCTAssertFalse(result?.methods.first?.isAsync ?? false)
    }
    
    func testParseMethodAsync() {
        let input = """
        protocol MyRouter {
            func fetchUser() async -> User
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.methods.first?.isAsync ?? false)
    }
    
    func testParseMethodAsyncThrows() {
        let input = """
        protocol MyRouter {
            func fetchUser() async throws -> User
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.methods.first?.isAsync ?? false)
        XCTAssertTrue(result?.methods.first?.isThrows ?? false)
    }
    
    // MARK: - Method Parsing (Multiline)
    
    func testParseMethodMultilineParameters() {
        let input = """
        protocol MyRouter {
            func openBottomSheet(
                model: BottomSheetTableViewModel,
                onSelected: ((IndexPath) -> Void)?,
                onClose: (() -> Void)?
            )
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        // FIXME: поправить
//        XCTAssertEqual(result?.methods.first?.parameters.count, 3)
        XCTAssertEqual(result?.methods.first?.parameters[0].name, "model")
    }
    
    func testParseMethodMultilineWithReturn() {
        let input = """
        protocol MyRouter {
            func fetchData(
                for id: String,
                completion: @escaping (Result<Data, Error>) -> Void
            ) -> URLSessionTask?
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.count, 2)
        XCTAssertEqual(result?.methods.first?.returnType, "URLSessionTask?")
    }
    
    // MARK: - Complex Protocol
    
    func testParseComplexProtocol() {
        let input = """
        protocol MyRouterProtocol: AnyObject {
            var currentPage: String { get }
            var isLoading: Bool { get }
            
            func openURL(url: URL)
            func openPDF(_ url: String)
            func dismissBottomSheet(completion: @escaping () -> Void)
            func openBottomSheet(
                model: BottomSheetTableViewModel,
                onSelected: ((IndexPath) -> Void)?,
                onClose: (() -> Void)?
            )
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouterProtocol")
        XCTAssertEqual(result?.properties.count, 2)
        XCTAssertEqual(result?.methods.count, 4)
    }
    
    // MARK: - Edge Cases
    
    func testParseProtocolEmptyBody() {
        let input = """
        protocol MyRouter {
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.count, 0)
        XCTAssertEqual(result?.properties.count, 0)
    }
    
    func testParseProtocolWithLeadingTrailingSpaces() {
        let input = """
               protocol    MyRouter   {
                    func navigate()
               }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouter")
    }
    
    func testParseMethodParameterWithExternalName() {
        let input = """
        protocol MyRouter {
            func navigate(to page: String)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.first?.name, "page")
    }
    
    func testParseMethodParameterWithUnderscore() {
        let input = """
        protocol MyRouter {
            func openPDF(_ url: String)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.first?.name, "url")
    }
    
    func testParseMethodClosureParameter() {
        let input = """
        protocol MyRouter {
            func handleResult(completion: @escaping (Result<Data, Error>) -> Void)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods.first?.parameters.count, 1)
        XCTAssertEqual(result?.methods.first?.parameters.first?.name, "completion")
    }
    
    func testParseProtocolWithDocumentation() {
        let input = """
        /// Router protocol for navigation
        /// - Note: Must be implemented by all routers
        protocol MyRouter {
            /// Navigate to a specific page
            /// - Parameter page: The page to navigate to
            func navigate(to page: String)
        }
        """
        
        let result = parser.parseProtocol(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "MyRouter")
        XCTAssertEqual(result?.methods.count, 1)
    }
}

class MockGenViewModelTests: XCTestCase {
    
    var viewModel: MockGenViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = MockGenViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization
    
    func testViewModelInitialState() {
        XCTAssertEqual(viewModel.protocolInput, "")
        XCTAssertEqual(viewModel.generatedMock, "")
        XCTAssertEqual(viewModel.moduleName, "YourModule")
        XCTAssertEqual(viewModel.authorName, "Developer")
        XCTAssertEqual(viewModel.appName, "YourApp")
    }
    
    // MARK: - Settings
    
    func testSaveAndLoadSettings() {
        viewModel.moduleName = "TestModule"
        viewModel.authorName = "TestAuthor"
        viewModel.appName = "TestApp"
        viewModel.saveSettings()
        
        let newViewModel = MockGenViewModel()
        newViewModel.loadSettings()
        
        XCTAssertEqual(newViewModel.moduleName, "TestModule")
        XCTAssertEqual(newViewModel.authorName, "TestAuthor")
        XCTAssertEqual(newViewModel.appName, "TestApp")
    }
    
    // MARK: - Mock Generation
    
    func testGenerateMockEmptyInput() {
        viewModel.protocolInput = ""
        viewModel.generateMock()
        
        XCTAssertEqual(viewModel.generatedMock, "")
    }
    
    func testGenerateMockValidProtocol() {
        let input = """
        protocol MyRouter {
            func navigate()
        }
        """
        viewModel.protocolInput = input
        viewModel.generateMock()
        
        XCTAssertNotEqual(viewModel.generatedMock, "")
        XCTAssertFalse(viewModel.generatedMock.contains("Error:"))
    }
    
    func testGenerateMockInvalidProtocol() {
        viewModel.protocolInput = "invalid protocol syntax {"
        viewModel.generateMock()
        
        // Should either generate with best effort or show error
        // FIXME: обработка ошибок
//        XCTAssertTrue(
//            viewModel.generatedMock.isEmpty || viewModel.generatedMock.contains("Error:")
//        )
    }
    
    func testGenerateMockWithProperties() {
        let input = """
        protocol MyRouter {
            var currentPage: String { get }
            func navigate()
        }
        """
        viewModel.protocolInput = input
        viewModel.generateMock()
        
        XCTAssertNotEqual(viewModel.generatedMock, "")
        XCTAssertTrue(viewModel.generatedMock.contains("currentPage"))
    }
    
    func testGenerateMockWithMultipleMethods() {
        let input = """
        protocol MyRouter {
            func openURL(url: URL)
            func openPDF(_ url: String)
            func dismiss()
        }
        """
        viewModel.protocolInput = input
        viewModel.generateMock()
        
        XCTAssertNotEqual(viewModel.generatedMock, "")
        XCTAssertTrue(viewModel.generatedMock.contains("openURL"))
        XCTAssertTrue(viewModel.generatedMock.contains("openPDF"))
        XCTAssertTrue(viewModel.generatedMock.contains("dismiss"))
    }
    
    func testGenerateMockIncludesAuthorInfo() {
        viewModel.authorName = "John Doe"
        viewModel.appName = "MyApp"
        viewModel.moduleName = "MyModule"
        viewModel.protocolInput = "protocol MyRouter { func navigate() }"
        viewModel.generateMock()
        
        XCTAssertTrue(viewModel.generatedMock.contains("John Doe"))
        XCTAssertTrue(viewModel.generatedMock.contains("MyApp"))
    }
    
    // MARK: - Published Properties
    
    func testProtocolInputPublished() {
        let expectation = XCTestExpectation(description: "protocolInput published")
        var cancellable: Any?
        
        cancellable = viewModel.$protocolInput.sink { _ in
            expectation.fulfill()
        }
        
        viewModel.protocolInput = "protocol Test { }"
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGeneratedMockPublished() {
        let expectation = XCTestExpectation(description: "generatedMock published")
        var cancellable: Any?
        
        cancellable = viewModel.$generatedMock.sink { _ in
            expectation.fulfill()
        }
        
        viewModel.generateMock()
        
        wait(for: [expectation], timeout: 1.0)
    }
}

class MockGenCodeGeneratorTests: XCTestCase {
    
    var generator: MockGenCodeGenerator!
    
    func testGenerateMockBasicStructure() {
        let protocolDef = ProtocolDefinition(
            name: "MyRouter",
            properties: [],
            methods: [
                ProtocolMethod(
                    name: "navigate",
                    parameters: [],
                    returnType: "Void",
                    isAsync: false,
                    isThrows: false,
                    fullSignature: "func navigate()",
                    originalSignature: nil
                )
            ]
        )
        
        generator = MockGenCodeGenerator(
            protocolDef: protocolDef,
            authorName: "Test",
            appName: "TestApp",
            moduleName: "TestModule"
        )
        
        let mockFile = generator.generateMock()
        
        XCTAssertFalse(mockFile.content.isEmpty)
        XCTAssertTrue(mockFile.content.contains("class MyRouterMock"))
        XCTAssertTrue(mockFile.content.contains("MyRouter"))
    }
    
    func testGenerateMockWithProperties() {
        let protocolDef = ProtocolDefinition(
            name: "MyRouter",
            properties: [
                ProtocolProperty(name: "currentPage", type: "String")
            ],
            methods: []
        )
        
        generator = MockGenCodeGenerator(
            protocolDef: protocolDef,
            authorName: "Test",
            appName: "TestApp",
            moduleName: "TestModule"
        )
        
        let mockFile = generator.generateMock()
        XCTAssertTrue(mockFile.content.contains("currentPage"))
    }
    
    func testGenerateMockIncludesHeader() {
        let protocolDef = ProtocolDefinition(
            name: "MyRouter",
            properties: [],
            methods: []
        )
        
        generator = MockGenCodeGenerator(
            protocolDef: protocolDef,
            authorName: "John Doe",
            appName: "MyApp",
            moduleName: "MyModule"
        )
        
        let mockFile = generator.generateMock()
        XCTAssertTrue(mockFile.content.contains("John Doe"))
        XCTAssertTrue(mockFile.content.contains("MyApp"))
    }
}
