//
//  OnboardingLanguagesView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct OnboardingLanguagesView: View {
  @ObservedObject var viewModel: OnboardingViewModel

  let onContinue: () -> Void

  private let background = BPDesign.Colors.inkBackground
  private let card = BPDesign.Colors.surface
  private let accent = BPDesign.Colors.coral
  private let subtle = BPDesign.Colors.textSecondaryDark

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          HStack(alignment: .firstTextBaseline) {
            Text("onboarding_languages_title")
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(.white)

            Spacer()

            Text("\(viewModel.selectedLanguages.count)/\(OnboardingViewModel.maxLanguages)")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(subtle)
          }

          Text(String(format: "onboarding_languages_subtitle".localized, OnboardingViewModel.maxLanguages))
            .font(.system(size: 15))
            .foregroundStyle(subtle)

          VStack(spacing: Spacing.S2) {
            ForEach(OnboardingLanguage.all) { language in
              languageRow(language)
            }
          }
          .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
      }

      BPPrimaryButton(
        title: "onboarding_continue",
        isEnabled: !viewModel.selectedLanguages.isEmpty,
        action: onContinue
      )
      .padding(.horizontal, Spacing.M)
      .padding(.bottom, Spacing.S)
    }
    .background(background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .tint(.white)
  }

  private func languageRow(_ language: OnboardingLanguage) -> some View {
    let isSelected = viewModel.isLanguageSelected(language)
    let isAtLimit = !isSelected && viewModel.selectedLanguages.count >= OnboardingViewModel.maxLanguages
    let isDeviceLanguage = language.id == OnboardingViewModel.deviceLanguageId()

    return Button {
      viewModel.toggleLanguage(language)
    } label: {
      HStack(spacing: Spacing.S) {
        Text(language.nativeName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.white)

        if isDeviceLanguage {
          Text("onboarding_language_device_tag")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
            .padding(.horizontal, Spacing.S2)
            .padding(.vertical, Spacing.S5)
            .background(accent.opacity(0.15))
            .clipShape(Capsule())
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundStyle(isSelected ? accent : subtle.opacity(0.5))
      }
      .padding(Spacing.S)
      .bpSelectableSurface(isSelected: isSelected)
      .opacity(isAtLimit ? 0.35 : 1)
    }
    .buttonStyle(.plain)
    .disabled(isAtLimit)
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }
}

#Preview {
  NavigationStack {
    OnboardingLanguagesView(viewModel: OnboardingViewModel(), onContinue: {})
  }
}
