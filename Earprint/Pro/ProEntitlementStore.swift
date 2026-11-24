import Foundation
import Observation
import StoreKit

struct AppTransactionInfo: Equatable, Sendable {
    enum EnvironmentKind: Equatable, Sendable { case production, sandbox, xcode, other }

    var environment: EnvironmentKind
    var originalAppVersion: String
}

protocol AppTransactionProviding: Sendable {
    func currentAppTransaction() async -> AppTransactionInfo?
    func refreshAppTransaction() async -> AppTransactionInfo?
}

extension AppTransactionProviding {
    func refreshAppTransaction() async -> AppTransactionInfo? {
        await currentAppTransaction()
    }
}

struct StoreKitAppTransactionProvider: AppTransactionProviding {
    func currentAppTransaction() async -> AppTransactionInfo? {
        mapVerification(try? await AppTransaction.shared)
    }

    func refreshAppTransaction() async -> AppTransactionInfo? {
        mapVerification(try? await AppTransaction.refresh())
    }

    private func mapVerification(_ result: VerificationResult<AppTransaction>?) -> AppTransactionInfo? {
        guard case .verified(let appTx)? = result else { return nil }

        let environment: AppTransactionInfo.EnvironmentKind
        switch appTx.environment {
        case .production: environment = .production
        case .sandbox: environment = .sandbox
        case .xcode: environment = .xcode
        default: environment = .other
        }
        return AppTransactionInfo(environment: environment, originalAppVersion: appTx.originalAppVersion)
    }
}

struct StoreProductItem: Identifiable, Equatable, Sendable {
    var id: String
    var displayPrice: String
    var price: Decimal
}

enum ProPurchaseOutcome: Equatable, Sendable {
    case purchased(revoked: Bool)
    case userCancelled
    case pending
    case unverified
    case failed(String)
}

enum ProStoreEvent: Sendable {
    case entitlementChanged(hasPro: Bool)
    case tipPurchased(id: UInt64, productID: String)
}

protocol ProStoreClient: Sendable {
    func fetchProducts(ids: [String]) async throws -> [StoreProductItem]
    func currentProEntitled() async -> Bool
    func purchase(productID: String) async -> ProPurchaseOutcome
    func syncPurchases() async throws
    func updatesStream() -> AsyncStream<ProStoreEvent>
}

actor LiveProStoreClient: ProStoreClient {
    private var productsByID: [String: Product] = [:]
    private static let purchaseFailureMessage = "The purchase could not be completed. Please try again."

    func fetchProducts(ids: [String]) async throws -> [StoreProductItem] {
        let products = try await Product.products(for: ids)
        for product in products { productsByID[product.id] = product }
        return products.map { StoreProductItem(id: $0.id, displayPrice: $0.displayPrice, price: $0.price) }
    }

    func currentProEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == EarprintProductID.proLifetime.rawValue,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func purchase(productID: String) async -> ProPurchaseOutcome {
        guard let product = productsByID[productID] else { return .failed(Self.purchaseFailureMessage) }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                return .purchased(revoked: transaction.revocationDate != nil)
            case .success(.unverified):
                return .unverified
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(Self.purchaseFailureMessage)
            }
        } catch {
            return .failed(Self.purchaseFailureMessage)
        }
    }

    func syncPurchases() async throws {
        try await AppStore.sync()
    }

    nonisolated func updatesStream() -> AsyncStream<ProStoreEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await update in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    guard case .verified(let transaction) = update,
                          let productID = EarprintProductID(rawValue: transaction.productID) else { continue }

                    if productID == .proLifetime {
                        continuation.yield(.entitlementChanged(hasPro: await currentProEntitled()))
                    } else if transaction.revocationDate == nil {
                        continuation.yield(.tipPurchased(id: transaction.id, productID: transaction.productID))
                    }
                    await transaction.finish()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
@Observable
final class ProEntitlementStore: ProEntitlementProviding {
    enum EligibilityState: Equatable, Sendable {
        case checking
        case resolved
        case unavailable
    }

    private(set) var hasProPurchased = false
    private(set) var isGrandfathered = false
    private(set) var eligibilityState: EligibilityState = .checking
    private(set) var proProduct: StoreProductItem?

    var hasResolvedEntitlements: Bool { eligibilityState == .resolved || hasPro }
    private(set) var tipProducts: [StoreProductItem] = []
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?
    private(set) var purchasedTipCount = 0

    private let storeClient: any ProStoreClient
    private let appTransactionProvider: any AppTransactionProviding
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var startupTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var deliveredTipIDs: Set<UInt64> = []

    var hasPro: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-proUnlocked") { return true }
        #endif
        return hasProPurchased || isGrandfathered
    }

    var accessSnapshot: ProAccessSnapshot {
        ProAccessSnapshot(hasPro: hasPro, isGrandfathered: isGrandfathered)
    }

    init(
        storeClient: any ProStoreClient = LiveProStoreClient(),
        appTransactionProvider: any AppTransactionProviding = StoreKitAppTransactionProvider(),
        autoStart: Bool = true
    ) {
        self.storeClient = storeClient
        self.appTransactionProvider = appTransactionProvider
        if autoStart { start() }
    }

    deinit {
        updatesTask?.cancel()
        startupTask?.cancel()
    }

    nonisolated static func shouldGrandfather(_ info: AppTransactionInfo?) -> Bool {
        guard let info, info.environment == .production else { return false }
        let trimmed = info.originalAppVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let buildNumber = Int(trimmed) else { return false }
        return buildNumber < 10
    }

    func start() {
        guard updatesTask == nil else { return }
        let updates = storeClient.updatesStream()
        updatesTask = Task { [weak self] in
            for await update in updates {
                guard !Task.isCancelled, let self else { return }
                switch update {
                case .entitlementChanged(let hasPro):
                    await self.refreshEntitlements(knownPurchased: hasPro)
                case .tipPurchased(let id, let productID):
                    if EarprintProductID.isTip(productID), self.deliveredTipIDs.insert(id).inserted {
                        self.recordTip()
                    }
                }
            }
        }
        startupTask = Task { [weak self] in
            guard let self else { return }
            async let products: Void = self.loadProducts()
            await self.refreshEntitlements()
            await products
        }
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        errorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let products = try await storeClient.fetchProducts(ids: EarprintProductID.allCases.map(\.rawValue))
            guard !Task.isCancelled else { return }
            proProduct = products.first { $0.id == EarprintProductID.proLifetime.rawValue }
            tipProducts = products.filter { EarprintProductID.isTip($0.id) }.sorted { $0.price < $1.price }
        } catch {
            if !Task.isCancelled, !isPurchasing {
                errorMessage = "The store is unavailable right now."
            }
        }
    }

    func refreshEntitlements() async {
        await refreshEntitlements(knownPurchased: nil, forceAppTransactionRefresh: false)
    }

    private func refreshEntitlements(knownPurchased: Bool?, forceAppTransactionRefresh: Bool = false) async {
        refreshGeneration += 1
        let generation = refreshGeneration
        let provider = appTransactionProvider
        async let appTransaction: AppTransactionInfo? = forceAppTransactionRefresh
            ? provider.refreshAppTransaction()
            : provider.currentAppTransaction()

        let purchased: Bool
        if let knownPurchased {
            purchased = knownPurchased
        } else {
            purchased = await storeClient.currentProEntitled()
        }
        // A slower scan must not replace the results of a newer refresh.
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        hasProPurchased = purchased

        let info = await appTransaction
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        if let info {
            isGrandfathered = Self.shouldGrandfather(info)
            eligibilityState = .resolved
        } else {
            isGrandfathered = false
            eligibilityState = .unavailable
        }
    }

    func retryEligibilityCheck() async {
        errorMessage = nil
        eligibilityState = .checking
        await refreshEntitlements(knownPurchased: nil, forceAppTransactionRefresh: true)
        if eligibilityState == .unavailable && !hasPro {
            errorMessage = "Could not verify early collector eligibility. Please try again."
        }
    }

    @discardableResult
    func purchasePro() async -> Bool {
        if !hasResolvedEntitlements {
            await refreshEntitlements(knownPurchased: nil, forceAppTransactionRefresh: eligibilityState == .unavailable)
        }
        if hasPro { return true }
        guard hasResolvedEntitlements else {
            errorMessage = "Could not verify early collector eligibility. Please try again."
            return false
        }
        guard let proProduct else { return false }
        return await purchase(proProduct)
    }

    @discardableResult
    func purchase(_ product: StoreProductItem) async -> Bool {
        guard !isPurchasing, let productID = EarprintProductID(rawValue: product.id) else { return false }
        if productID == .proLifetime {
            if !hasResolvedEntitlements {
                await refreshEntitlements(knownPurchased: nil, forceAppTransactionRefresh: eligibilityState == .unavailable)
            }
            if hasPro { return true }
            guard hasResolvedEntitlements else {
                errorMessage = "Could not verify early collector eligibility. Please try again."
                return false
            }
        }
        isPurchasing = true
        statusMessage = nil
        errorMessage = nil
        defer { isPurchasing = false }

        switch await storeClient.purchase(productID: product.id) {
        case .purchased(let revoked):
            if productID == .proLifetime {
                await refreshEntitlements()
            } else if !revoked {
                recordTip()
            }
            return !revoked
        case .userCancelled:
            break
        case .pending:
            statusMessage = "Your purchase is pending."
        case .unverified:
            errorMessage = "This purchase could not be verified."
        case .failed(let message):
            errorMessage = message
        }
        return false
    }

    func restorePurchases() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        statusMessage = nil
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await storeClient.syncPurchases()
            await refreshEntitlements()
            statusMessage = hasProPurchased ? "Purchases restored." : "No previous Pro purchase was found."
        } catch {
            errorMessage = "Purchases could not be restored. Please try again."
        }
    }

    private func recordTip() {
        purchasedTipCount += 1
        statusMessage = "Thank you for supporting Earprint."
        errorMessage = nil
    }
}
