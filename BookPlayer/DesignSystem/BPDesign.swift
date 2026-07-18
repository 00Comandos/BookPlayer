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

    /// Background for full-screen flows; follows the phone's appearance
    static let inkBackground = adaptive(light: "F7F7F9", dark: "101014")
    /// Card/tile surface on ink background
    static let surface = adaptive(light: "FFFFFF", dark: "1C1E24")
    /// Elevated surface (chips, banners, mini-player)
    static let surfaceElevated = adaptive(light: "ECEEF1", dark: "242424")
    /// Disabled CTA surface
    static let surfaceDisabled = adaptive(light: "C9CDD4", dark: "2A2C33")
    /// Media browsing background: always dark, like most media UIs
    static let mediaBackground = Color(UIColor(hex: "121212"))
    /// Elevated surface inside the always-dark media UI
    static let mediaSurfaceElevated = Color(UIColor(hex: "242424"))

    /// Primary text; navy on light, white on dark
    static let textPrimary = adaptive(light: "132237", dark: "FFFFFF")
    /// Secondary text on flow surfaces
    static let textSecondary = adaptive(light: "5F6570", dark: "9A9DA5")
    /// Secondary text in (always dark) media browsing contexts
    static let textSecondaryMedia = Color(UIColor(hex: "B3B3B3"))

    /// Convenience for appearance-aware brand colors
    static func adaptive(light: String, dark: String) -> Color {
      Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
      })
    }
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
    /// Subtle outline for cards, appearance-aware
    static let hairlineColor = Color(UIColor { trait in
      trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.07)
        : UIColor.black.withAlphaComponent(0.08)
    })
    /// Selection outline: navy on light, white on dark
    static let selectedColor = BPDesign.Colors.adaptive(light: "132237", dark: "FFFFFF")
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
            isSelected ? BPDesign.Border.selectedColor : BPDesign.Border.hairlineColor,
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
