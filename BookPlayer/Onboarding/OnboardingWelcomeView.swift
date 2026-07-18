//
//  OnboardingWelcomeView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct OnboardingWelcomeView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  let onImportAudiobooks: () -> Void
  let onBrowseCatalog: () -> Void

  var body: some View {
    VStack(spacing: Spacing.M) {
      Spacer()

      Image(systemName: "headphones.circle.fill")
        .font(.system(size: 72))
        .foregroundStyle(theme.linkColor)

      VStack(spacing: Spacing.S2) {
        Text("onboarding_welcome_title")
          .bpFont(.titleStory)
          .foregroundStyle(theme.primaryColor)
          .multilineTextAlignment(.center)

        Text("onboarding_welcome_subtitle")
          .bpFont(.body)
          .foregroundStyle(theme.secondaryColor)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, Spacing.M)

      Spacer()

      VStack(spacing: Spacing.S1) {
        welcomeOptionCard(
          systemImage: "square.and.arrow.down.fill",
          title: "onboarding_import_option_title",
          subtitle: "onboarding_import_option_description",
          action: onImportAudiobooks
        )

        welcomeOptionCard(
          systemImage: "rectangle.grid.2x2.fill",
          title: "onboarding_catalog_option_title",
          subtitle: "onboarding_catalog_option_description",
          action: onBrowseCatalog
        )
      }
      .padding(.horizontal, Spacing.M)
      .padding(.bottom, Spacing.L)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(theme.systemBackgroundColor.ignoresSafeArea())
  }

  private func welcomeOptionCard(
    systemImage: String,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: Spacing.S) {
        Image(systemName: systemImage)
          .font(.system(size: 24))
          .foregroundStyle(theme.linkColor)
          .frame(width: 44, height: 44)
          .background(theme.linkColor.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 10))

        VStack(alignment: .leading, spacing: Spacing.S4) {
          Text(title)
            .bpFont(.title)
            .foregroundStyle(theme.primaryColor)
            .multilineTextAlignment(.leading)

          Text(subtitle)
            .bpFont(.footnote)
            .foregroundStyle(theme.secondaryColor)
            .multilineTextAlignment(.leading)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(theme.secondaryColor)
      }
      .padding(Spacing.S)
      .background(theme.secondarySystemBackgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    OnboardingWelcomeView(onImportAudiobooks: {}, onBrowseCatalog: {})
  }
  .environmentObject(ThemeViewModel())
}
