//
//  LoadingViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import Themeable
import UIKit

class LoadingViewController: UIViewController, MVVMControllerProtocol, Storyboarded, Themeable {
  var viewModel: LoadingViewModel!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationController?.isNavigationBarHidden = true

    embedSplashAnimation()

    // Subscribe to theme changes to ensure proper initial rendering
    setUpTheming()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.navigationController?.isNavigationBarHidden = true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    self.viewModel.initializeDataIfNeeded()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  private func embedSplashAnimation() {
    let host = UIHostingController(rootView: SplashAnimationView())
    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    host.didMove(toParent: self)
  }

  func applyTheme(_ theme: SimpleTheme) {
    /// Splash keeps the brand navy regardless of theme, matching LaunchScreen
    self.view.backgroundColor = UIColor(hex: "132237")
  }
}

/// Animated brand isotype: book-spine bars rise like an equalizer with a
/// staggered spring, then the leaning book tilts into place.
/// Proportions mirror bookplayer-isotype.svg.
struct SplashAnimationView: View {
  private struct Bar: Identifiable {
    let id: Int
    /// Height relative to the isotype width
    let height: CGFloat
    let hex: String
  }

  private let bars: [Bar] = [
    .init(id: 0, height: 0.31, hex: "FD9E83"),
    .init(id: 1, height: 0.46, hex: "FDA38A"),
    .init(id: 2, height: 0.68, hex: "FD6746"),
    .init(id: 3, height: 0.54, hex: "FE5A3C"),
    .init(id: 4, height: 0.46, hex: "FE9C82"),
  ]

  @State private var barsVisible = false
  @State private var bookSettled = false

  var body: some View {
    GeometryReader { geometry in
      let width = min(geometry.size.width, geometry.size.height) * 0.5
      let barWidth = width * 0.115
      let spacing = width * 0.038
      let corner = barWidth * 0.18

      ZStack {
        Color(UIColor(hex: "132237"))
          .ignoresSafeArea()

        HStack(alignment: .bottom, spacing: spacing) {
          ForEach(bars) { bar in
            RoundedRectangle(cornerRadius: corner)
              .fill(Color(UIColor(hex: bar.hex)))
              .frame(width: barWidth, height: width * bar.height)
              .scaleEffect(y: barsVisible ? 1 : 0.05, anchor: .bottom)
              .animation(
                .spring(response: 0.55, dampingFraction: 0.62)
                  .delay(Double(bar.id) * 0.09),
                value: barsVisible
              )
          }

          RoundedRectangle(cornerRadius: corner)
            .fill(Color(UIColor(hex: "1F536E")))
            .frame(width: barWidth, height: width * 0.34)
            .rotationEffect(.degrees(bookSettled ? -15 : 0), anchor: .bottomLeading)
            .opacity(bookSettled ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.55), value: bookSettled)
        }
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
      }
    }
    .background(Color(UIColor(hex: "132237")).ignoresSafeArea())
    .onAppear {
      barsVisible = true
      bookSettled = true
    }
  }
}

#Preview {
  SplashAnimationView()
}
