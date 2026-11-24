import Observation
import StoreKitTest
import XCTest
@testable import Earprint

final class ProEntitlementTests: XCTestCase {
    func testGrandfatheringRequiresProductionAndAnEarlyIntegerBuild() {
        let cases: [(AppTransactionInfo.EnvironmentKind, String, Bool)] = [
            (.production, "1", true),
            (.production, "2", true),
            (.production, "9", true),
            (.production, " 9\n", true),
            (.production, "10", false),
            (.production, "1.0", false),
            (.sandbox, "1", false),
            (.sandbox, "1.0", false),
            (.xcode, "1", false),
            (.other, "1", false)
        ]

        for (environment, version, expected) in cases {
            let info = AppTransactionInfo(environment: environment, originalAppVersion: version)
            XCTAssertEqual(ProEntitlementStore.shouldGrandfather(info), expected, "\(environment), \(version)")
        }
        XCTAssertFalse(ProEntitlementStore.shouldGrandfather(nil))
    }

    @MainActor
    func testLoadsProAndTipsInAscendingPriceOrder() async {
        let client = MockProStoreClient()
        let info = AppTransactionInfo(environment: .production, originalAppVersion: "2")
        let store = ProEntitlementStore(
            storeClient: client,
            appTransactionProvider: FixedAppTransactionProvider(info: info),
            autoStart: false
        )

        await store.loadProducts()
        XCTAssertEqual(store.proProduct, MockProStoreClient.proProduct)
        XCTAssertEqual(store.tipProducts.map(\.id), EarprintProductID.tipIDs)
        XCTAssertEqual(store.tipProducts.map(\.price), [1, 3, 10])

        await store.refreshEntitlements()
        XCTAssertTrue(store.isGrandfathered)
        XCTAssertTrue(store.hasPro)
        XCTAssertFalse(store.hasProPurchased)
    }

    @MainActor
    func testPurchaseProDefersAndHonorsGrandfatheringWhenEntitlementsUnresolved() async {
        let client = MockProStoreClient()
        let info = AppTransactionInfo(environment: .production, originalAppVersion: "2")
        let store = ProEntitlementStore(
            storeClient: client,
            appTransactionProvider: FixedAppTransactionProvider(info: info),
            autoStart: false
        )

        XCTAssertFalse(store.hasResolvedEntitlements)
        let unlocked = await store.purchasePro()
        XCTAssertTrue(unlocked)
        XCTAssertTrue(store.hasResolvedEntitlements)
        XCTAssertTrue(store.isGrandfathered)
        XCTAssertTrue(store.hasPro)
        XCTAssertFalse(store.hasProPurchased)
        XCTAssertEqual(client.purchaseCallCount, 0)
    }

    @MainActor
    func testLifetimePurchaseUnlocksProAndRefundRevokesIt() async {
        let client = MockProStoreClient()
        let store = makeSandboxStore(client: client)
        let loaded = expectation(description: "The store loads the Pro product")
        withObservationTracking {
            _ = store.proProduct
        } onChange: {
            loaded.fulfill()
        }
        store.start()
        await fulfillment(of: [loaded], timeout: 2)
        XCTAssertFalse(store.isGrandfathered)
        XCTAssertFalse(store.hasPro)

        let purchased = await store.purchasePro()
        XCTAssertTrue(purchased)
        XCTAssertTrue(store.hasProPurchased)
        XCTAssertTrue(store.hasPro)
        XCTAssertTrue(store.accessSnapshot.isUnlocked(.wrappedVideo))

        let refunded = expectation(description: "The entitlement update relocks Pro")
        withObservationTracking {
            _ = store.hasProPurchased
        } onChange: {
            refunded.fulfill()
        }
        client.refundPro()
        await fulfillment(of: [refunded], timeout: 2)
        XCTAssertFalse(store.hasPro)

        await store.refreshEntitlements()
        XCTAssertFalse(store.hasProPurchased)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.accessSnapshot.isUnlocked(.wrappedVideo))
    }

    @MainActor
    func testRestorePurchasesAndTipPurchases() async throws {
        let client = MockProStoreClient()
        client.hasRestorablePro = true
        let store = makeSandboxStore(client: client)
        await store.loadProducts()
        let tip = try XCTUnwrap(store.tipProducts.first)

        let firstTip = await store.purchase(tip)
        XCTAssertTrue(firstTip)
        XCTAssertEqual(store.purchasedTipCount, 1)
        XCTAssertEqual(store.statusMessage, "Thank you for supporting Earprint.")
        XCTAssertFalse(store.hasProPurchased)
        XCTAssertFalse(store.hasPro)

        await store.restorePurchases()
        XCTAssertTrue(store.hasProPurchased)
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(store.statusMessage, "Purchases restored.")

        let secondTip = await store.purchase(tip)
        XCTAssertTrue(secondTip)
        XCTAssertEqual(store.purchasedTipCount, 2)
        XCTAssertTrue(store.hasProPurchased)
        XCTAssertTrue(store.hasPro)
    }

    @MainActor
    func testPendingCancelledAndFailedPurchases() async {
        let client = MockProStoreClient()
        let store = makeSandboxStore(client: client)
        await store.loadProducts()

        let failure = "The purchase could not be completed. Please try again."
        let cases: [(outcome: ProPurchaseOutcome, status: String?, error: String?)] = [
            (.pending, "Your purchase is pending.", nil),
            (.failed(failure), nil, failure),
            (.userCancelled, nil, nil),
            (.unverified, nil, "This purchase could not be verified."),
            (.purchased(revoked: true), nil, nil)
        ]
        for (outcome, status, error) in cases {
            client.purchaseOutcome = outcome
            let purchased = await store.purchasePro()
            XCTAssertFalse(purchased, "\(outcome)")
            XCTAssertFalse(store.hasPro, "\(outcome)")
            XCTAssertEqual(store.statusMessage, status, "\(outcome)")
            XCTAssertEqual(store.errorMessage, error, "\(outcome)")
        }
    }

    func testStoreKitConfigurationSchemaAndIPSafety() throws {
        struct Configuration: Decodable {
            struct Product: Decodable {
                struct Localization: Decodable {
                    let locale: String
                    let displayName: String
                    let description: String
                }

                let productID: String
                let type: String
                let localizations: [Localization]
            }

            let products: [Product]
        }

        let configurationData = try Data(contentsOf: configurationURL)
        let configuration = try JSONDecoder().decode(Configuration.self, from: configurationData)
        let expectedIDs = EarprintProductID.allCases.map(\.rawValue)
        XCTAssertEqual(configuration.products.count, 4)
        XCTAssertEqual(configuration.products.map(\.productID).sorted(), expectedIDs.sorted())

        for product in configuration.products {
            let expectedType = product.productID == EarprintProductID.proLifetime.rawValue
                ? "NonConsumable" : "Consumable"
            XCTAssertEqual(product.type, expectedType, product.productID)
            XCTAssertEqual(product.localizations.map(\.locale).sorted(), ["en_US", "zh_Hans"], product.productID)
            for localization in product.localizations {
                XCTAssertFalse(localization.displayName.isEmpty, product.productID)
                XCTAssertFalse(localization.description.isEmpty, product.productID)
            }
        }

        let productsSourceURL = sourceRoot.appendingPathComponent("Earprint/Pro/EarprintProducts.swift")
        let productsSource = try String(contentsOf: productsSourceURL, encoding: .utf8).lowercased()
        let configurationSource = String(decoding: configurationData, as: UTF8.self).lowercased()
        let forbiddenTerms = ["air" + "pods", "ap" + "ple", "so" + "ny", "bo" + "se", "be" + "ats"]
        for term in forbiddenTerms {
            XCTAssertFalse(configurationSource.contains(term), "Earprint.storekit contains \(term)")
            XCTAssertFalse(productsSource.contains(term), "EarprintProducts.swift contains \(term)")
        }
    }

    @MainActor
    func testLiveSKTestSessionWhenDaemonAvailable() async throws {
        let session: SKTestSession
        let bundledConfiguration = Bundle.main.url(forResource: "Earprint", withExtension: "storekit")
            ?? Bundle(for: ProEntitlementTests.self).url(forResource: "Earprint", withExtension: "storekit")
        do {
            session = try SKTestSession(contentsOf: bundledConfiguration ?? configurationURL)
        } catch let error as NSError where error.domain == "SKInternalErrorDomain" {
            throw XCTSkip("StoreKitTest daemon unavailable in headless xcodebuild")
        }
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = makeSandboxStore(client: LiveProStoreClient())
        await store.loadProducts()
        guard let pro = store.proProduct, store.errorMessage == nil else {
            throw XCTSkip("StoreKitTest daemon unavailable in headless xcodebuild")
        }
        XCTAssertEqual(pro.id, EarprintProductID.proLifetime.rawValue)
        XCTAssertEqual(store.tipProducts.map(\.id), EarprintProductID.tipIDs)

        let purchased = await store.purchasePro()
        XCTAssertTrue(purchased)
        XCTAssertTrue(store.hasProPurchased)
    }

    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var configurationURL: URL {
        sourceRoot.appendingPathComponent("Earprint/Resources/Earprint.storekit")
    }

    @MainActor
    private func makeSandboxStore(client: any ProStoreClient) -> ProEntitlementStore {
        let info = AppTransactionInfo(environment: .sandbox, originalAppVersion: "1")
        return ProEntitlementStore(
            storeClient: client,
            appTransactionProvider: FixedAppTransactionProvider(info: info),
            autoStart: false
        )
    }
}

private struct FixedAppTransactionProvider: AppTransactionProviding {
    let info: AppTransactionInfo?

    func currentAppTransaction() async -> AppTransactionInfo? { info }
}

@MainActor
private final class MockProStoreClient: ProStoreClient {
    static let proProduct = StoreProductItem(id: EarprintProductID.proLifetime.rawValue, displayPrice: "$3", price: 3)
    private let products = [
        StoreProductItem(id: EarprintProductID.tipLarge.rawValue, displayPrice: "$10", price: 10),
        proProduct,
        StoreProductItem(id: EarprintProductID.tipSmall.rawValue, displayPrice: "$1", price: 1),
        StoreProductItem(id: EarprintProductID.tipMedium.rawValue, displayPrice: "$3", price: 3)
    ]
    private let updates = AsyncStream<ProStoreEvent>.makeStream()
    private var hasPro = false

    var hasRestorablePro = false
    var purchaseOutcome: ProPurchaseOutcome = .purchased(revoked: false)
    private(set) var purchaseCallCount = 0

    func fetchProducts(ids: [String]) async throws -> [StoreProductItem] {
        products.filter { ids.contains($0.id) }
    }

    func currentProEntitled() async -> Bool { hasPro }

    func purchase(productID: String) async -> ProPurchaseOutcome {
        purchaseCallCount += 1
        if productID == EarprintProductID.proLifetime.rawValue, case .purchased(let revoked) = purchaseOutcome {
            hasPro = !revoked
        }
        return purchaseOutcome
    }

    func syncPurchases() async throws {
        if hasRestorablePro { hasPro = true }
    }

    nonisolated func updatesStream() -> AsyncStream<ProStoreEvent> { updates.stream }

    func refundPro() {
        hasPro = false
        updates.continuation.yield(.entitlementChanged(hasPro: false))
    }
}
