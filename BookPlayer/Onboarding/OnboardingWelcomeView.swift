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
        .containerRelativeFrame(.vertical) { length, _ in length * 0.66 }
        .clipped()
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
          imageName: "lucide-upload",
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

  /// Bundled hero playlist: onboarding-hero-1/2/3.mp4 chained seamlessly
  private var heroPlaylist: [URL] {
    (1...3).compactMap {
      Bundle.main.url(forResource: "onboarding-hero-\($0)", withExtension: "mp4")
    }
  }

  /// Top hero area: a muted looping playlist of short clips, falling back
  /// to a single `onboarding-hero.mp4`, then the `onboarding-hero` image
  /// asset, and lastly to a themed placeholder
  @ViewBuilder
  private var heroView: some View {
    if !heroPlaylist.isEmpty {
      LoopingVideoView(urls: heroPlaylist)
    } else if let videoURL = Bundle.main.url(forResource: "onboarding-hero", withExtension: "mp4") {
      LoopingVideoView(urls: [videoURL])
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

/// Muted, autoplaying playlist that loops endlessly (no playback controls).
/// The clips are stitched into a single composition so the A→B→C→A cycle
/// has no gaps or black frames between videos.
private struct LoopingVideoView: UIViewRepresentable {
  let urls: [URL]

  func makeUIView(context: Context) -> PlayerContainerView {
    PlayerContainerView(urls: urls)
  }

  func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

  final class PlayerContainerView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    init(urls: [URL]) {
      super.init(frame: .zero)

      let playerLayer = layer as! AVPlayerLayer
      playerLayer.player = queuePlayer
      playerLayer.videoGravity = .resizeAspectFill
      queuePlayer.isMuted = true

      Task { [weak self] in
        await self?.setUpPlaylist(urls)
      }
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    /// Concatenate the video tracks (audio is dropped entirely) and loop
    /// the resulting composition
    @MainActor
    private func setUpPlaylist(_ urls: [URL]) async {
      let composition = AVMutableComposition()
      guard
        let compositionTrack = composition.addMutableTrack(
          withMediaType: .video,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else { return }

      var cursor = CMTime.zero
      for url in urls {
        let asset = AVURLAsset(url: url)
        guard
          let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
          let duration = try? await asset.load(.duration)
        else { continue }

        try? compositionTrack.insertTimeRange(
          CMTimeRange(start: .zero, duration: duration),
          of: videoTrack,
          at: cursor
        )
        cursor = CMTimeAdd(cursor, duration)

        if cursor == duration,
          let transform = try? await videoTrack.load(.preferredTransform)
        {
          compositionTrack.preferredTransform = transform
        }
      }

      guard cursor > .zero else { return }

      looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(asset: composition))
      queuePlayer.play()
    }
  }
}

#Preview {
  NavigationStack {
    OnboardingWelcomeView(onImportAudiobooks: {}, onBrowseCatalog: {})
  }
  .environmentObject(ThemeViewModel())
}
