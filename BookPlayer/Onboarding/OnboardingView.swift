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
          viewModel.persistPreferences()
          onFinish(.importAudiobooks)
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
          OnboardingLanguagesView(viewModel: viewModel)
        case .catalog:
          OnboardingCatalogView(viewModel: viewModel) {
            viewModel.persistPreferences()
            onFinish(.finishedCatalog)
          }
        }
      }
    }
    .tint(theme.linkColor)
    .onAppear {
      ThemeManager.shared.checkSystemMode()
    }
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
  }
}

/// Shared bottom CTA style for the onboarding steps
struct OnboardingPrimaryButton: View {
  @EnvironmentObject private var theme: ThemeViewModel

  let title: LocalizedStringKey
  var isEnabled: Bool = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .contentShape(Rectangle())
        .bpFont(.headline)
        .frame(height: 45)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .background(isEnabled ? theme.linkColor : Color(UIColor.systemGray3))
        .cornerRadius(10)
    }
    .disabled(!isEnabled)
    .padding(.horizontal, Spacing.M)
    .padding(.bottom, Spacing.S)
  }
}

#Preview {
  OnboardingView { _ in }
    .environmentObject(ThemeViewModel())
}
