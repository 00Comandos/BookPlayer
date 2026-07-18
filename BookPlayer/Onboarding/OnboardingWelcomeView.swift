//
//  OnboardingWelcomeView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import SwiftUI

struct OnboardingWelcomeView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  let onImportAudiobooks: () -> Void
  let onBrowseCatalog: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      heroView
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in length * 0.58 }
        .clipShape(
          UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24)
        )
        .ignoresSafeArea(edges: .top)

      Spacer()

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
      .padding(.bottom, Spacing.M)

      VStack(spacing: Spacing.S1) {
        welcomeOptionCard(
          imageName: "lucide-download",
          title: "onboarding_import_option_title",
          subtitle: "onboarding_import_option_description",
          action: onImportAudiobooks
        )

        welcomeOptionCard(
          imageName: "lucide-book-headphones",
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

  /// Top hero area: a short muted looping video when the bundle includes
  /// `onboarding-hero.mp4`, falling back to the `onboarding-hero` image
  /// asset, and lastly to a themed placeholder
  @ViewBuilder
  private var heroView: some View {
    if let videoURL = Bundle.main.url(forResource: "onboarding-hero", withExtension: "mp4") {
      LoopingVideoView(url: videoURL)
    } else if UIImage(named: "onboarding-hero") != nil {
      Image("onboarding-hero")
        .resizable()
        .scaledToFill()
    } else {
      ZStack {
        theme.linkColor.opacity(0.12)
        Image(systemName: "headphones.circle.fill")
          .font(.system(size: 72))
          .foregroundStyle(theme.linkColor)
      }
    }
  }

  private func welcomeOptionCard(
    imageName: String,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: Spacing.S) {
        Image(imageName)
          .resizable()
          .renderingMode(.template)
          .scaledToFit()
          .frame(width: 22, height: 22)
          .foregroundStyle(theme.linkColor)
          .frame(width: 44, height: 44)
          .background(theme.linkColor.opacity(0.10))
          .clipShape(Circle())

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

/// Muted, autoplaying, endlessly looping video (no playback controls)
private struct LoopingVideoView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> PlayerContainerView {
    PlayerContainerView(url: url)
  }

  func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

  final class PlayerContainerView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    init(url: URL) {
      super.init(frame: .zero)

      let playerLayer = layer as! AVPlayerLayer
      playerLayer.player = queuePlayer
      playerLayer.videoGravity = .resizeAspectFill

      looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
      queuePlayer.isMuted = true
      queuePlayer.play()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
}

#Preview {
  NavigationStack {
    OnboardingWelcomeView(onImportAudiobooks: {}, onBrowseCatalog: {})
  }
  .environmentObject(ThemeViewModel())
}
