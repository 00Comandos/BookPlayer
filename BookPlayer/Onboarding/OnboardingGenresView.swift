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

  private let background = BPDesign.Colors.inkBackground
  private let card = BPDesign.Colors.surface
  private let accent = BPDesign.Colors.coral
  private let subtle = BPDesign.Colors.textSecondary

  private let columns = [
    GridItem(.flexible(), spacing: Spacing.S1),
    GridItem(.flexible(), spacing: Spacing.S1),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          HStack(alignment: .firstTextBaseline) {
            Text("onboarding_genres_title")
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(BPDesign.Colors.textPrimary)

            Spacer()

            Text("\(viewModel.selectedGenres.count)/\(OnboardingViewModel.maxGenres)")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(subtle)
          }

          Text(String(format: "onboarding_genres_subtitle".localized, OnboardingViewModel.maxGenres))
            .font(.system(size: 15))
            .foregroundStyle(subtle)

          LazyVGrid(columns: columns, spacing: Spacing.S1) {
            ForEach(OnboardingGenre.all) { genre in
              genreCard(genre)
            }
          }
          .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
      }

      BPPrimaryButton(
        title: "onboarding_continue",
        isEnabled: !viewModel.selectedGenres.isEmpty
      ) {
        viewModel.path.append(.languages)
      }
      .padding(.horizontal, Spacing.M)
      .padding(.bottom, Spacing.S)
    }
    .background(background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
        .tint(BPDesign.Colors.textPrimary)
  }

  private func genreCard(_ genre: OnboardingGenre) -> some View {
    let isSelected = viewModel.isGenreSelected(genre)
    let isAtLimit = !isSelected && viewModel.selectedGenres.count >= OnboardingViewModel.maxGenres

    return Button {
      viewModel.toggleGenre(genre)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        Image(systemName: genre.systemImage)
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(isSelected ? accent : BPDesign.Colors.textPrimary.opacity(0.85))

        Spacer(minLength: Spacing.S)

        Text(genre.title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(BPDesign.Colors.textPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(2)
      }
      .padding(Spacing.S1)
      .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
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
    OnboardingGenresView(viewModel: OnboardingViewModel())
  }
}
