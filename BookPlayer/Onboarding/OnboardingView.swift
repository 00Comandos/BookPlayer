//
//  OnboardingView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct OnboardingView: View {
  @StateObject private var viewModel = OnboardingViewModel()
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.colorScheme) private var scheme

  let onFinish: (OnboardingOutcome) -> Void

  var body: some View {
    NavigationStack(path: $viewModel.path) {
      OnboardingWelcomeView(
        onImportAudiobooks: {
          viewModel.path.append(.uploads)
        },
        onBrowseCatalog: {
          viewModel.path.append(.genres)
        }
      )
      .navigationDestination(for: OnboardingViewModel.Step.self) { step in
        switch step {
        case .genres:
          OnboardingGenresView(viewModel: viewModel)
        case .languages:
          OnboardingLanguagesView(viewModel: viewModel) {
            viewModel.persistPreferences()
            onFinish(.finishedCatalog)
          }
        case .uploads:
          UploadsView(style: .adaptive, title: "uploads_title_personal") { urls in
            viewModel.persistPreferences()
            onFinish(.importAudiobooks(urls: urls))
          }
        }
      }
    }
    .tint(BPDesign.Colors.coral)
    .onAppear {
      ThemeManager.shared.checkSystemMode()
    }
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
  }
}

#Preview {
  OnboardingView { _ in }
    .environmentObject(ThemeViewModel())
}
