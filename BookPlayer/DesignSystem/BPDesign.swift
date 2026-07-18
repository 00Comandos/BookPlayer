//
//  BPDesign.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// Brand design system introduced with the onboarding redesign.
/// Use these tokens instead of raw hex values so the new visual language
/// can spread through the app from a single source of truth.
enum BPDesign {
  enum Colors {
    /// Brand navy: splash and icon background, dark headlines
    static let navy = Color(UIColor(hex: "132237"))
    /// Brand coral: primary CTAs, active states, accents
    static let coral = Color(UIColor(hex: "FD6746"))
    static let coralSoft = Color(UIColor(hex: "FE9C82"))
    /// Leaning-book blue from the isotype
    static let bookBlue = Color(UIColor(hex: "1F536E"))

    /// Background for dark full-screen flows (preferences, media browsing)
    static let inkBackground = Color(UIColor(hex: "101014"))
    /// Card/tile surface on ink background
    static let surface = Color(UIColor(hex: "1C1E24"))
    /// Elevated surface for media UI (chips, banners, mini-player)
    static let surfaceElevated = Color(UIColor(hex: "242424"))
    /// Disabled CTA surface on dark
    static let surfaceDisabled = Color(UIColor(hex: "2A2C33"))
    /// Media browsing background (near-black)
    static let mediaBackground = Color(UIColor(hex: "121212"))

    /// Secondary text on dark surfaces
    static let textSecondaryDark = Color(UIColor(hex: "9A9DA5"))
    /// Secondary text in media browsing contexts
    static let textSecondaryMedia = Color(UIColor(hex: "B3B3B3"))
  }

  enum Radius {
    static let card: CGFloat = 12
    static let cover: CGFloat = 6
    static let button: CGFloat = 12
    static let banner: CGFloat = 12
  }

  enum Border {
    static let hairline: CGFloat = 1
    static let selected: CGFloat = 1.5
    /// Subtle outline for cards on dark surfaces
    static let hairlineColor = Color.white.opacity(0.07)
  }
}

/// Full-width brand CTA used at the bottom of dark flow screens
struct BPPrimaryButton: View {
  let title: LocalizedStringKey
  var isEnabled: Bool = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(isEnabled ? BPDesign.Colors.coral : BPDesign.Colors.surfaceDisabled)
        .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.button))
    }
    .disabled(!isEnabled)
  }
}

/// Selection outline used by cards and rows in preference screens
struct BPSelectableSurface: ViewModifier {
  let isSelected: Bool

  func body(content: Content) -> some View {
    content
      .background(BPDesign.Colors.surface)
      .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
      .overlay(
        RoundedRectangle(cornerRadius: BPDesign.Radius.card)
          .stroke(
            isSelected ? Color.white : BPDesign.Border.hairlineColor,
            lineWidth: isSelected ? BPDesign.Border.selected : BPDesign.Border.hairline
          )
      )
  }
}

extension View {
  func bpSelectableSurface(isSelected: Bool) -> some View {
    modifier(BPSelectableSurface(isSelected: isSelected))
  }
}
