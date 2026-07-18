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
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S2) {
          Text("onboarding_languages_title")
            .bpFont(.titleStory)
            .foregroundStyle(theme.primaryColor)

          Text(String(format: "onboarding_languages_subtitle".localized, OnboardingViewModel.maxLanguages))
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)

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

      OnboardingPrimaryButton(
        title: "onboarding_continue",
        isEnabled: !viewModel.selectedLanguages.isEmpty
      ) {
        viewModel.path.append(.catalog)
      }
    }
    .background(theme.systemBackgroundColor.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("\(viewModel.selectedLanguages.count)/\(OnboardingViewModel.maxLanguages)")
          .bpFont(.captionMedium)
          .foregroundStyle(theme.secondaryColor)
      }
    }
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
          .bpFont(.title)
          .foregroundStyle(theme.primaryColor)

        if isDeviceLanguage {
          Text("onboarding_language_device_tag")
            .bpFont(.buttonTextSmall)
            .foregroundStyle(theme.linkColor)
            .padding(.horizontal, Spacing.S2)
            .padding(.vertical, Spacing.S5)
            .background(theme.linkColor.opacity(0.12))
            .clipShape(Capsule())
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundStyle(isSelected ? theme.linkColor : theme.separatorColor)
      }
      .padding(Spacing.S)
      .background(theme.secondarySystemBackgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? theme.linkColor : Color.clear, lineWidth: 1.5)
      )
      .opacity(isAtLimit ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .disabled(isAtLimit)
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }
}

#Preview {
  NavigationStack {
    OnboardingLanguagesView(viewModel: OnboardingViewModel())
  }
  .environmentObject(ThemeViewModel())
}
