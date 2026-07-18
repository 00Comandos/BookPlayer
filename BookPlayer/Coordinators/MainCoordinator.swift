//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import RevenueCat
import SwiftUI
import Themeable
import UIKit

@MainActor
class MainCoordinator: NSObject {
  var mainController: UIViewController?

  let importManager: ImportManager
  let playerManager: PlayerManager
  let playerLoaderService: PlayerLoaderService
  let singleFileDownloadService: SingleFileDownloadService
  let libraryService: LibraryService
  let playbackService: PlaybackService
  let listSyncRefreshService: ListSyncRefreshService
  let accountService: AccountService
  var syncService: SyncService
  let watchConnectivityService: PhoneWatchConnectivityService
  let jellyfinConnectionService: JellyfinConnectionService
  let audiobookshelfConnectionService: AudiobookShelfConnectionService
  let hardcoverService: HardcoverService
  let preferencesService: PreferencesSyncService

  var playerState: PlayerState { AppServices.shared.playerState }

  /// Reference to know if the import screen is already being shown (or in the process of showing)
  weak var importCoordinator: ImportCoordinator?
  let navigationController: UINavigationController

  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    coreServices: CoreServices
  ) {
    self.navigationController = navigationController
    self.libraryService = coreServices.libraryService
    self.importManager = ImportManager(libraryService: coreServices.libraryService)
    self.accountService = coreServices.accountService
    self.syncService = coreServices.syncService
    self.playbackService = coreServices.playbackService
    self.playerManager = coreServices.playerManager
    self.playerLoaderService = coreServices.playerLoaderService
    self.listSyncRefreshService = ListSyncRefreshService(
      playerManager: playerManager,
      syncService: syncService,
      playerLoaderService: coreServices.playerLoaderService,
      preferencesService: coreServices.preferencesService
    )
    self.singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient())
    self.watchConnectivityService = coreServices.watchService
    let jellyfinService = JellyfinConnectionService()
    jellyfinService.setup()
    self.jellyfinConnectionService = jellyfinService

    let audiobookshelfService = AudiobookShelfConnectionService()
    audiobookshelfService.setup()
    self.audiobookshelfConnectionService = audiobookshelfService

    self.hardcoverService = coreServices.hardcoverService
    self.preferencesService = coreServices.preferencesService

    ThemeManager.shared.libraryService = libraryService

    super.init()

    setUpTheming()
  }

  func start() {
    if var currentTheme = libraryService.getLibraryCurrentTheme() {
      currentTheme.useDarkVariant = ThemeManager.shared.useDarkVariant
      ThemeManager.shared.currentTheme = currentTheme
    }

    bindObservers()

    accountService.loginIfUserExists(delegate: self)

    let vc = AppHostingViewController(
      rootView: MainView {
        self.showSecondOnboarding()
      } showImport: {
        self.showImport()
      }
      .environmentObject(singleFileDownloadService)
      .environmentObject(importManager)
      .environmentObject(playerManager)
      .environmentObject(listSyncRefreshService)
      .environment(\.libraryService, libraryService)
      .environment(\.accountService, accountService)
      .environment(\.syncService, syncService)
      .environment(\.jellyfinService, jellyfinConnectionService)
      .environment(\.audiobookshelfService, audiobookshelfConnectionService)
      .environment(\.hardcoverService, hardcoverService)
      .environment(\.playerState, playerState)
      .environment(\.playerLoaderService, playerLoaderService)
      .environment(\.playbackService, playbackService)
      .environment(\.preferencesService, preferencesService)
    )
    vc.modalPresentationStyle = .fullScreen
    vc.modalTransitionStyle = .crossDissolve
    
    // Set window interface style BEFORE presenting the view controller
    // This ensures SwiftUI views are initialized with the correct colorScheme
    if let window = navigationController.view.window ?? WindowHelper.activeWindow {
      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled) {
        window.overrideUserInterfaceStyle = .unspecified
      } else {
        window.overrideUserInterfaceStyle = ThemeManager.shared.useDarkVariant ? .dark : .light
      }
    }
    
    /// Keep the settled splash on top during the handoff into the onboarding,
    /// so the library never flashes in between
    var splashHost: UIHostingController<SplashAnimationView>?
    if !UserDefaults.standard.bool(forKey: Constants.UserDefaults.completedOnboarding),
      let window = navigationController.view.window ?? WindowHelper.activeWindow
    {
      let host = UIHostingController(rootView: SplashAnimationView(animated: false))
      host.view.frame = window.bounds
      host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      window.addSubview(host.view)
      splashHost = host
    }

    navigationController.present(vc, animated: false) { [weak self] in
      #if DEBUG
      if ProcessInfo.processInfo.environment["BP_PREVIEW_CATALOG"] == "1" {
        self?.showCatalogHome()
        splashHost?.view.removeFromSuperview()
        return
      }
      #endif
      self?.showFirstTimeOnboarding {
        guard let splashHost else { return }
        UIView.animate(withDuration: 0.3, delay: 0.1) {
          splashHost.view.alpha = 0
        } completion: { _ in
          splashHost.view.removeFromSuperview()
        }
      }
    }
    mainController = vc

    AppServices.shared.coreServices?.watchService.startSession()
  }

  /// One-time welcome flow: import your audiobooks or browse the catalog
  /// picking genre and language preferences
  func showFirstTimeOnboarding(onPresented: (() -> Void)? = nil) {
    guard
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.completedOnboarding),
      let mainController
    else {
      onPresented?()
      return
    }

    let vc = AppHostingViewController(
      rootView: OnboardingView { [weak self] outcome in
        UserDefaults.standard.set(true, forKey: Constants.UserDefaults.completedOnboarding)
        self?.mainController?.dismiss(animated: false) {
          if case .finishedCatalog = outcome {
            self?.showCatalogHome()
          }
        }
      }
      .environmentObject(ThemeViewModel())
      .environment(\.accountService, accountService)
    )
    vc.modalPresentationStyle = .fullScreen
    vc.modalTransitionStyle = .crossDissolve

    mainController.present(vc, animated: false, completion: onPresented)
  }

  /// Spotify-style catalog browser, entry point after the onboarding's
  /// "browse our catalog" route
  func showCatalogHome() {
    guard let mainController else { return }

    let vc = AppHostingViewController(
      rootView: CatalogHomeView(
        onClose: { [weak self] in
          self?.mainController?.dismiss(animated: true)
        },
        onUploadOwn: { [weak self] in
          /// Land on the library, where the existing import flow lives
          self?.mainController?.dismiss(animated: true)
        }
      )
      .environmentObject(ThemeViewModel())
      .environment(\.accountService, accountService)
    )
    vc.modalPresentationStyle = .fullScreen
    vc.modalTransitionStyle = .crossDissolve

    mainController.present(vc, animated: false)
  }

  func showSecondOnboarding() {
    /// Don't compete with the first-time onboarding flow
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.completedOnboarding) else { return }

    guard let anonymousId = accountService.getAnonymousId() else { return }

    let coordinator = SecondOnboardingCoordinator(
      flow: .modalOnlyFlow(
        presentingController: mainController!,
        modalPresentationStyle: .fullScreen
      ),
      anonymousId: anonymousId,
      accountService: accountService,
      eventsService: EventsService()
    )
    coordinator.start()
  }

  func showImport() {
    guard
      importManager.hasPendingFiles(),
      importCoordinator == nil,
      let topVC = WindowHelper.activeWindow?.rootViewController?.getTopVisibleViewController()
    else { return }

    let coordinator = ImportCoordinator(
      flow: .modalFlow(presentingController: topVC),
      importManager: self.importManager
    )
    importCoordinator = coordinator
    coordinator.start()
  }

  func bindObservers() {
    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.playerState.loadedBookRelativePath = item?.relativePath
      }
      .store(in: &disposeBag)
  }

  func loadPlayer(_ relativePath: String, autoplay: Bool, showPlayer: Bool) {
    Task { @MainActor in
      let alertPresenter: AlertPresenter = self
      do {
        try await AppServices.shared.coreServices?.playerLoaderService.loadPlayer(
          relativePath,
          autoplay: autoplay
        )
        if showPlayer {
          self.showPlayer()
        }
      } catch BPPlayerError.fileMissing {
        alertPresenter.showAlert(
          "file_missing_title".localized,
          message:
            "\("file_missing_description".localized)\n\(relativePath)",
          completion: nil
        )
      } catch {
        alertPresenter.showAlert(
          "error_title".localized,
          message: error.localizedDescription,
          completion: nil
        )
      }
    }
  }

  func showPlayer() {
    playerState.showPlayer = true
  }
  
  func hasPlayerShown() -> Bool {
    return playerState.isShowingPlayer
  }

  func processFiles(urls: [URL]) {
    let temporaryDirectoryPath = FileManager.default.temporaryDirectory.absoluteString
    let documentsFolder = DataManager.getDocumentsFolderURL()

    for url in urls {
      /// At some point (iOS 17?), the OS stopped sending the picked files to the Documents/Inbox folder, instead
      /// it's now sent to a temp folder that can't be relied on to keep the file existing until the import is finished
      if url.absoluteString.contains(temporaryDirectoryPath) {
        let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          try! FileManager.default.copyItem(at: url, to: destinationURL)
          destinationURL.disableFileProtection()
        }
      } else {
        importManager.process(url)
      }
    }
  }
}

extension MainCoordinator: PurchasesDelegate {
  nonisolated public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    Task { @MainActor in
      self.accountService.updateAccount(from: customerInfo)
    }
  }
}

extension MainCoordinator: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    guard
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled)
    else {
      WindowHelper.activeWindow?.overrideUserInterfaceStyle = .unspecified
      return
    }
    // This fixes native components like alerts having the proper color theme
    WindowHelper.activeWindow?.overrideUserInterfaceStyle =
      theme.useDarkVariant
      ? .dark
      : .light
  }
}

extension MainCoordinator: AlertPresenter {
  func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    mainController?.showAlert(title, message: message, completion: completion)
  }

  func showAlert(_ content: BPAlertContent) {
    mainController?.showAlert(content)
  }

  func showLoader() {
    LoadingUtils.loadAndBlock(in: mainController!)
  }

  func stopLoader() {
    LoadingUtils.stopLoading(in: mainController!)
  }
}
