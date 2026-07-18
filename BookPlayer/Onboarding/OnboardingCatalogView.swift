//
//  OnboardingCatalogView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct OnboardingCatalogView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.accountService) private var accountService

  let onFinish: () -> Void

  @State private var showLogin = false
  @State private var pendingBook: CatalogBook?

  private let columns = [
    GridItem(.flexible(), spacing: Spacing.S1),
    GridItem(.flexible(), spacing: Spacing.S1),
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S2) {
          Text("onboarding_catalog_title")
            .bpFont(.titleStory)
            .foregroundStyle(theme.primaryColor)

          Text("onboarding_catalog_subtitle")
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)

          LazyVGrid(columns: columns, spacing: Spacing.S1) {
            ForEach(viewModel.filteredBooks) { book in
              bookCard(book)
            }
          }
          .padding(.top, Spacing.S)

          Text("onboarding_catalog_sample_note")
            .bpFont(.footnote)
            .foregroundStyle(theme.secondaryColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
        .padding(.bottom, Spacing.M)
      }

      if let nowPlaying = viewModel.nowPlayingBook {
        nowPlayingBanner(nowPlaying)
      }

      OnboardingPrimaryButton(title: "onboarding_go_library") {
        onFinish()
      }
    }
    .background(theme.systemBackgroundColor.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showLogin, onDismiss: handleLoginDismiss) {
      NavigationStack {
        LoginView()
      }
    }
  }

  private func bookCard(_ book: CatalogBook) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S2) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 12)
          .fill(book.coverGradient)
          .frame(height: 140)
          .overlay(
            Image(systemName: book.coverSymbol)
              .font(.system(size: 42))
              .foregroundStyle(.white.opacity(0.9))
          )

        Button {
          handlePlay(book)
        } label: {
          Image(systemName: viewModel.nowPlayingBook == book ? "waveform.circle.fill" : "play.circle.fill")
            .font(.system(size: 34))
            .foregroundStyle(.white, .black.opacity(0.35))
        }
        .padding(Spacing.S2)
        .accessibilityLabel(Text("onboarding_catalog_play"))
      }

      VStack(alignment: .leading, spacing: Spacing.S5) {
        Text(book.title)
          .bpFont(.miniPlayerTitle)
          .foregroundStyle(theme.primaryColor)
          .lineLimit(1)

        Text(book.author)
          .bpFont(.miniPlayerAuthor)
          .foregroundStyle(theme.secondaryColor)
          .lineLimit(1)

        HStack(spacing: Spacing.S3) {
          if let genre = book.genre {
            Text(genre.title)
              .lineLimit(1)
          }
          Text("·")
          Text(book.language?.id.uppercased() ?? "")
          Text("·")
          Text(book.durationDescription)
        }
        .bpFont(.buttonTextSmall)
        .foregroundStyle(theme.secondaryColor)
      }
    }
    .padding(Spacing.S2)
    .background(theme.secondarySystemBackgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private func nowPlayingBanner(_ book: CatalogBook) -> some View {
    HStack(spacing: Spacing.S1) {
      RoundedRectangle(cornerRadius: 6)
        .fill(book.coverGradient)
        .frame(width: 40, height: 40)
        .overlay(
          Image(systemName: "waveform")
            .font(.system(size: 16))
            .foregroundStyle(.white)
        )

      VStack(alignment: .leading, spacing: Spacing.S5) {
        Text("onboarding_playing_demo")
          .bpFont(.buttonTextSmall)
          .foregroundStyle(theme.linkColor)

        Text("\(book.title) — \(book.author)")
          .bpFont(.miniPlayerTitle)
          .foregroundStyle(theme.primaryColor)
          .lineLimit(1)
      }

      Spacer()

      Button {
        viewModel.nowPlayingBook = nil
      } label: {
        Image(systemName: "stop.circle")
          .font(.system(size: 24))
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .padding(Spacing.S1)
    .background(theme.secondarySystemBackgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, Spacing.M)
    .padding(.bottom, Spacing.S2)
  }

  /// Playing the first catalog book requires an account: present the existing
  /// login flow, which chains into the subscription modal after registration
  private func handlePlay(_ book: CatalogBook) {
    if accountService.hasAccount() {
      viewModel.nowPlayingBook = book
    } else {
      pendingBook = book
      showLogin = true
    }
  }

  private func handleLoginDismiss() {
    guard let book = pendingBook else { return }
    pendingBook = nil

    /// The paywall is a soft-sell: dismissing it still allows playback
    if accountService.hasAccount() {
      viewModel.nowPlayingBook = book
    }
  }
}

#Preview {
  NavigationStack {
    OnboardingCatalogView(viewModel: OnboardingViewModel()) {}
  }
  .environmentObject(ThemeViewModel())
}
