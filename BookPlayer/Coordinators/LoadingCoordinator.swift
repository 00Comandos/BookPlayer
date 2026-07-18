//
//  LoadingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class LoadingCoordinator: Coordinator, AlertPresenter {
  let flow: BPCoordinatorPresentationFlow
  var mainCoordinator: MainCoordinator?

  /// Give the splash isotype animation time to complete before moving on
  private static let minimumSplashDuration: TimeInterval = 1.6
  private var splashStartedAt: Date?

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  func start() {
    let viewModel = LoadingViewModel()
    viewModel.coordinator = self
    let vc = LoadingViewController.instantiate(from: .Main)
    vc.viewModel = viewModel
    splashStartedAt = Date()
    flow.startPresentation(vc, animated: false)
  }

  @MainActor func didFinishLoadingSequence() {
    let elapsed = splashStartedAt.map { Date().timeIntervalSince($0) } ?? Self.minimumSplashDuration
    let remaining = max(0, Self.minimumSplashDuration - elapsed)

    DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
      guard let self else { return }

      let coreServices = AppServices.shared.coreServices!

      let coordinator = MainCoordinator(
        navigationController: self.flow.navigationController,
        coreServices: coreServices
      )
      self.mainCoordinator = coordinator

      coordinator.start()
    }
  }

  func getMainCoordinator() -> MainCoordinator? {
    return mainCoordinator
  }
}
