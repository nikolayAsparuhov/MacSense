import Foundation

/// Every user-visible string in the app maps to one of these keys.
/// Adding a UI string = adding a case here + an entry in every
/// `*Translations` table. The compiler then enforces full coverage
/// during translation work.
enum LocalizationKey: String, CaseIterable {
    // MARK: - Common verbs / shared
    case commonRefresh
    case commonClose
    case commonCancel
    case commonSave
    case commonGotIt
    case commonReadMore
    case commonSearch
    case commonOpen
    case commonRescan
    case commonStop
    case commonDiscover
    case commonScan
    case commonHelp

    // MARK: - Navigation / sections
    case navCleanup
    case navPerformance
    case navApplications
    case navStorage

    // MARK: - Cleanup
    case cleanupTitle
    case cleanupTagline
    case cleanupSummaryTitle
    case cleanupSummaryFoundPrefix
    case cleanupSummaryFoundSuffix
    case cleanupSummaryEmpty
    case cleanupSummaryScanning
    case cleanupScanningProgress
    case cleanupScanningGeneric

    // MARK: - Cleanup categories
    case categorySystemJunk
    case categorySystemJunkSubtitle
    case categoryUserCache
    case categoryUserCacheSubtitle
    case categoryTrashBins
    case categoryTrashBinsSubtitle
    case categoryPurgeable
    case categoryPurgeableSubtitle
    case categoryDevCaches
    case categoryDevCachesSubtitle

    case categoryStateScanning
    case categoryStateCleaning
    case categoryStateFreed
    case categoryStateClean
    case categoryStateTapToScan
    case categoryItemsCount

    // MARK: - Cleanup schedule
    case scheduleTitle
    case scheduleTaglineEnabled
    case scheduleTaglineDisabled
    case scheduleOff
    case scheduleCadence
    case scheduleCategories
    case scheduleConstraintNote
    case scheduleLastRunPrefix
    case scheduleLastRunSuffix
    case schedulePermissionDenied
    case schedulePermissionOpenSettings
    case scheduleSummaryUnit
    case scheduleSummaryUnits

    case cadenceDaily
    case cadenceWeekly
    case cadenceMonthly

    // MARK: - Storage
    case storageTitle
    case storageTagline
    case storageScanningFiles
    case storageTabSize
    case storageTabType
    case storageUsedFreeFormat
    case storageScanning
    case storageReScan
    case storageBubbleEmpty

    // MARK: - Applications
    case applicationsInstalledTab
    case applicationsUnusedTab
    case applicationsLoginItemsTab

    case installedHeroTitle
    case installedHeroTagline
    case installedHeroDiscover
    case installedHeroDiscovering

    case unusedHeroTitle
    case unusedHeroTagline
    case unusedHeader
    case unusedNeverOpened
    case unusedDaysAgoSuffix
    case unusedSectionStale
    case unusedSectionNeverOpened
    case unusedNothingStale
    case unusedNothingStaleBody
    case unusedAppsCountStaleNever

    // MARK: - Media types
    case mediaVideos
    case mediaPhotos
    case mediaAudio
    case mediaArchives
    case mediaDocuments
    case mediaCode
    case mediaOther
    case mediaFilesCount

    // MARK: - Login items
    case loginItemsUserGroup
    case loginItemsSystemGroup
    case loginItemsOpenSystemSettings

    // MARK: - Performance
    case performanceTitle
    case performanceLowPowerMode
    case performanceLive

    // MARK: - Network scan
    case networkDevicesTitle
    case networkScanningSubtitle
    case networkFoundDevices

    // MARK: - Help
    case helpTitle
    case helpSearchPlaceholder
    case helpReadMore
    case helpEntryMissing
    case helpEntryMissingBody
    case helpNoMatches

    // MARK: - Locale picker
    case languagePickerTitle

    // MARK: - Phase 1 sweep additions
    case commonSelectAll
    case commonDeselectAll
    case commonNoneFound
    case commonOpenSettings
    case commonSkipForNow
    case commonContinue
    case commonNext
    case commonBack
    case commonGetStarted
    case commonRefreshTooltip
    case commonSearchApps
    case commonSearchFiles
    case commonSearchAppsLogin
    case commonRetry
    case commonDelete
    case commonClean
    case commonInstall
    case commonUninstall
    case commonOK

    case installedAppsCountFormat            // "%d apps"
    case installedNoApps

    case categoryDetailSelectedFormat        // "%d of %d selected"
    case categoryDetailLocationsFormat       // "%d locations"
    case categoryDetailLocationFormat        // "%d location"
    case categoryDetailNothingToCleanTitle
    case categoryDetailNothingToCleanBody
    case categoryDetailCleanFormat           // "Clean %@"

    case onboardingGrantFDA
    case onboardingGrantedFDA

    case unusedDiscoverHint                  // "Discover apps first to scan for unused ones."
    case networkThisMac
    case processesTitle

    // Pass 1 sweep additions
    case perfCPU
    case perfRead
    case perfWrite
    case perfNetwork
    case perfNetworkInfo
    case perfPublic
    case perfMAC
    case perfThermal
    case perfDNSCache

    case wifiReading
    case wifiNoInterface
    case wifiLocationHint

    case processSearchPlaceholder
    case processSearchHint
    case processQuit
    case processForceQuit
    case processQuitDetail

    case uninstallFilesMoved
    case uninstallScanning
    case uninstallNoRelated
    case uninstallDeleteFormat       // "Delete %d files (%@)"

    case loginItemsSystemSettings
    case loginItemsNone
    case loginItemsBundledInside
    case loginItemsAdminWarning
    case loginItemsDeleteWarning

    case mediaTypeNoFiles            // "No files indexed yet"

    case bubbleMapSize
    case bubbleMapModifiedFormat     // "Modified: %@"

    case largeFilesTitle
    case largeFilesTagline
    case largeFilesMoveFormat        // "Move %d to Trash (%@)"

    case typeDetailTopFormat         // "Top 200 by size"

    case sizeTabDelete
    case sizeTabOtherItems
    case sizeTabEmptyMessage

    // Onboarding additions
    case onboardingGrantButton
    case onboardingBeginButton
    case onboardingPillProtection
    case onboardingPillManage
    case onboardingRequestBody
    case onboardingGrantedBody

    // Pass 2 sweep additions
    case commonClear
    case commonMoveToTrash
    case helpWhatIsThis
    case helpRevealPlist
    case helpTotalSize
    case helpQuitFormat            // "Quit %@"
    case helpShowProcesses
    case helpOpenNetwork
    case helpLowPowerHint
    case perfMemory
    case perfDisk
    case perfBattery
    case perfScanButton
    case perfFlushDNS
    case perfFlushing
    case perfNoBattery
    case storageBuildingGraph
    case sidebarTagline

    case processColName
    case processColMemory
    case processColUser
    case networkCopyIP
    case networkCopyMAC
    case networkCopyHostname
    case networkCopyRow

    // Pass 3 sweep additions
    case loginItemsScanning
    case loginItemsActionFailed
    case loginItemsErrorSuffix
    case loginItemsDeleteTitleFormat
    case loginItemsCountFormat
    case loginItemsHelpSMAppService
    case loginItemsTooltipBundled
    case loginItemsTooltipDelete
    case installedAppsDiscoveringProgress
    case processQuitTitleFormat
    case processCantQuitTitle
    case processQuitFailedFormat
    case processActionForceQuit
    case processActionQuit
    case removalFailedTitle
    case onboardingPillFindMoreJunk
    case thermalNominal
    case thermalFair
    case thermalSerious
    case thermalCritical
    case thermalHintNominal
    case thermalHintFair
    case thermalHintSerious
    case thermalHintCritical
    case bubbleMapDeselect
    case bubbleMapSelectDelete
    case bubbleMapMacintoshHD
    case bubbleMapVolume
    case bubbleMapApplications
    case bubbleMapUserFolder
    case bubbleMapYourFolder
    case bubbleMapSystemFolder
    case bubbleMapFolder
    case bubbleMapItemsFormat
    case sizeTabMoveTrashTitleSingular
    case sizeTabMoveTrashTitleFormat
    case sizeTabMoveTrashDetailFormat
    case sizeTabMoveTrashMoreFormat
    case sizeTabSidebarItemsFormat
    case sizeTabOtherItems2
    case storageOpenDetailsFormat
    case wifiConnLabel
    case wifiInterfaceLabel
    case wifiLinkSpeed
    case wifiSecurityLabel
    case wifiProtocolLabel
    case wifiLocalIP
    case wifiGatewayIP
    case wifiPublicIPLabel
    case wifiMACLabel
    case wifiBSSIDLabel
    case wifiDNSLabel
    case wifiRSSILabel
    case wifiNoiseLabel
    case wifiTXRate
    case wifiChannelLabel
    case wifiBandLabel
    case wifiWidthLabel
    case wifiKindWiFi
    case wifiKindEthernet
    case wifiKindUnknown
    case perfBatteryOnAC
    case perfBatteryToFullFormat
    case perfBatteryLeftFormat
    case perfBatteryCyclesFormat
    case perfDNSFlushSuccess
    case perfDNSFlushFailed
    case memoryNormal
    case memoryWarning
    case memoryCritical
    case batteryHealthGood
    case batteryHealthFair
    case batteryHealthPoor

    // Pass 4 sweep additions
    case perfProcessesRunningFormat       // "%d processes running"
    case perfPercentUsedFormat            // "%@ used"
    case perfThermalApprox                // "≈ approximate"
    case processRunningRefreshFormat      // "%d running · refreshing every 2s"
    case processShownFormat               // "%d shown"
    case uninstallDeletedFormat           // "%@ deleted"
    case uninstallSelectedOfFormat        // "%d of %d selected"
    case uninstallDeletedFilesFormat      // "Deleted %d files"
    // Match reasons — why a file was attributed to an app
    case matchReasonAppBundle             // "The application bundle"
    case matchReasonRule                  // "Matched a rule for this app"
    case matchReasonEntitlement           // "Declared by an app entitlement"
    case matchReasonBundleID              // "Named after the bundle identifier"
    case matchReasonPartialBundleID       // "Partial bundle identifier match"
    case matchReasonAppName               // "Named after the app"
    case matchReasonVendor                // "Vendor or developer identifier"
    case matchReasonContainer             // "Sandbox container for this app"

    // Uninstall safety assessment + exclusions
    case safetyLevelSafe
    case safetyLevelReview
    case safetyLevelHighRisk
    case safetyWarningSystemComponents
    case safetyWarningAdminRequired
    case safetyWarningLowConfidence
    case exclusionEncodedProjectPath
    case exclusionAppRule
    case exclusionSystemItem
    case exclusionHighRiskDotPath
    case exclusionProtectedLocation
    case exclusionOutsideScanRoots
    case exclusionMissing
    case uninstallExcludedSectionFormat
    case uninstallConfirmTitle
    case uninstallConfirmBodyFormat
    case uninstallConfirmAction
    case safetyWarningAppRunning
    case removalAppStillRunningFormat     // "%@ is still running."
    case uninstallPreparingRemoval
    case deletionModeTrash
    case deletionModePermanent
    case uninstallConfirmBodyPermanentFormat  // "%d items will be deleted permanently."
    case uninstallConfirmAdminFallbackFormat  // "%d items need a password and go to the Trash instead."
    case uninstallRevealLog
    case uninstallFilesDeleted
    case loginItemScopeUser               // "User"
    case loginItemScopeSystemAgent        // "System (Agent)"
    case loginItemScopeSystemDaemon       // "System (Daemon)"
    case loginItemBundledChunk            // " · Bundled"
    case typeTabMoreFormat                // "%d more…"
    case typeDetailFilesCountFormat       // "%d files · %@"
    case sizeTabSelectedCountFormat       // "%d selected · %@"

    // Pass 5 sweep additions
    case notifScheduledScanTitle          // "MacSense scheduled scan"
    case notifFoundRecoverableFormat      // "Found %@ recoverable across %d %@. Open MacSense to review."
    case notifNoRecoverableFormat         // "No recoverable space found across %d %@."
    case cleanupSomeItemsFailed           // "Some items could not be cleaned."
    case loginItemEnableAction
    case loginItemDisableAction
    case loginItemAdminSuffix
    case loginItemActionFailedFormat      // "Couldn't %@ %@.%@"

    // Pass 7 sweep additions
    case removalRefusedFormat             // "Refused to delete %d protected items."
    case removalAuthCancelledFormat       // "%d files not removed. Authorization cancelled or denied."
    case removalNotRemovedFormat          // "%d files could not be removed. %@"

    // FDA prompt
    case fdaPromptTitle
    case fdaPromptBody
    case fdaPromptOpenSettings
    case fdaPromptLater
}

/// Live, in-app localization service. Views read `loc.t(.someKey)`
/// from `body`; switching `locale` publishes a change and SwiftUI
/// re-renders everything that depended on the lookup.
@MainActor
final class Localization: ObservableObject {
    static let shared = Localization()

    private static let userDefaultsKey = "MacSense.Locale"

    @Published var locale: AppLocale {
        didSet {
            UserDefaults.standard.set(locale.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    private let tables: [AppLocale: [LocalizationKey: String]]

    private init() {
        // Boot: read the saved locale, or fall back to the system
        // preferred one. Using a temp local + assigning at the end
        // avoids triggering the didSet write-back during init.
        let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
            .flatMap(AppLocale.init(rawValue:))
        let resolved = saved ?? AppLocale.systemPreferred

        self.tables = [
            .en:     EnglishTranslations.table,
            .zhHans: MandarinTranslations.table,
            .hi:     HindiTranslations.table,
            .es:     SpanishTranslations.table,
            .fr:     FrenchTranslations.table,
            .bn:     BengaliTranslations.table,
            .pt:     PortugueseTranslations.table,
            .ru:     RussianTranslations.table,
            .de:     GermanTranslations.table,
        ]
        self.locale = resolved
    }

    /// Plain key lookup. Falls back to English, then to the raw
    /// key string itself so missing-translation bugs surface with
    /// the key name rather than empty space.
    func t(_ key: LocalizationKey) -> String {
        if let value = tables[locale]?[key], !value.isEmpty {
            return value
        }
        if let value = tables[.en]?[key], !value.isEmpty {
            return value
        }
        return key.rawValue
    }

    /// Interpolated lookup. Pass positional args for `%@`/`%d`/etc.
    /// in the translated format string.
    func t(_ key: LocalizationKey, _ args: CVarArg...) -> String {
        let format = t(key)
        return String(format: format, arguments: args)
    }
}
