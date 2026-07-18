//
//  OnboardingGenresView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct OnboardingGenresView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @EnvironmentObject private var theme: ThemeViewModel

  private let columns = [
    GridItem(.flexible(), spacing: Spacing.S1),
    GridItem(.flexible(), spacing: Spacing.S1),
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S2) {
          Text("onboarding_genres_title")
            .bpFont(.titleStory)
            .foregroundStyle(theme.primaryColor)

          Text(String(format: "onboarding_genres_subtitle".localized, OnboardingViewModel.maxGenres))
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)

          LazyVGrid(columns: columns, spacing: Spacing.S1) {
            ForEach(OnboardingGenre.all) { genre in
              genreChip(genre)
            }
          }
          .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
      }

      OnboardingPrimaryButton(
        title: "onboarding_continue",
        isEnabled: !viewModel.selectedGenres.isEmpty
      ) {
        viewModel.path.append(.languages)
      }
    }
    .background(theme.systemBackgroundColor.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("\(viewModel.selectedGenres.count)/\(OnboardingViewModel.maxGenres)")
          .bpFont(.captionMedium)
          .foregroundStyle(theme.secondaryColor)
      }
    }
  }

  private func genreChip(_ genre: OnboardingGenre) -> some View {
    let isSelected = viewModel.isGenreSelected(genre)
    let isAtLimit = !isSelected && viewModel.selectedGenres.count >= OnboardingViewModel.maxGenres

    return Button {
      viewModel.toggleGenre(genre)
    } label: {
      HStack(spacing: Spacing.S2) {
        Image(systemName: genre.systemImage)
          .font(.system(size: 16))
          .frame(width: 22)

        Text(genre.title)
          .bpFont(.captionMedium)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        Spacer(minLength: 0)

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16))
        }
      }
      .foregroundStyle(isSelected ? .white : theme.primaryColor)
      .padding(.horizontal, Spacing.S1)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .background(isSelected ? theme.linkColor : theme.secondarySystemBackgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .opacity(isAtLimit ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .disabled(isAtLimit)
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }
}

#Preview {
  NavigationStack {
    OnboardingGenresView(viewModel: OnboardingViewModel())
  }
  .environmentObject(ThemeViewModel())
}
