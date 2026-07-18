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

  @State private var searchQuery = ""

  private let background = BPDesign.Colors.inkBackground
  private let card = BPDesign.Colors.surface
  private let accent = BPDesign.Colors.coral
  private let subtle = BPDesign.Colors.textSecondary

  /// Device language pinned first, then selected ones, then the rest;
  /// filtered by the search query
  private var displayedLanguages: [OnboardingLanguage] {
    let deviceId = OnboardingViewModel.deviceLanguageId()
    let selected = viewModel.selectedLanguages
    let sorted = OnboardingLanguage.all.sorted { lhs, rhs in
      func rank(_ language: OnboardingLanguage) -> Int {
        if language.id == deviceId { return 0 }
        if selected.contains(language.id) { return 1 }
        return 2
      }
      let lhsRank = rank(lhs)
      let rhsRank = rank(rhs)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      return lhs.nativeName.localizedCaseInsensitiveCompare(rhs.nativeName) == .orderedAscending
    }

    guard !searchQuery.isEmpty else { return sorted }
    return sorted.filter {
      $0.nativeName.localizedCaseInsensitiveContains(searchQuery)
        || $0.id.localizedCaseInsensitiveContains(searchQuery)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          HStack(alignment: .firstTextBaseline) {
            Text("onboarding_languages_title")
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(BPDesign.Colors.textPrimary)

            Spacer()

            Text("\(viewModel.selectedLanguages.count)/\(OnboardingViewModel.maxLanguages)")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(subtle)
          }

          Text(String(format: "onboarding_languages_subtitle".localized, OnboardingViewModel.maxLanguages))
            .font(.system(size: 15))
            .foregroundStyle(subtle)

          searchField
            .padding(.top, Spacing.S)

          VStack(spacing: Spacing.S2) {
            ForEach(displayedLanguages) { language in
              languageRow(language)
            }
          }
          .padding(.top, Spacing.S2)
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
        .tint(BPDesign.Colors.textPrimary)
  }

  private var searchField: some View {
    HStack(spacing: Spacing.S2) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 15))
        .foregroundStyle(subtle)

      TextField(
        "",
        text: $searchQuery,
        prompt: Text("onboarding_languages_search_placeholder").foregroundStyle(subtle)
      )
      .font(.system(size: 15))
      .foregroundStyle(BPDesign.Colors.textPrimary)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)

      if !searchQuery.isEmpty {
        Button {
          searchQuery = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 15))
            .foregroundStyle(subtle)
        }
      }
    }
    .padding(.horizontal, Spacing.S1)
    .frame(height: 42)
    .background(card)
    .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
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
          .foregroundStyle(BPDesign.Colors.textPrimary)

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
