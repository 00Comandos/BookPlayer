//
//  OnboardingViewModel.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// How the user left the onboarding flow
enum OnboardingOutcome {
  case importAudiobooks
  case finishedCatalog
}

@MainActor
final class OnboardingViewModel: ObservableObject {
  enum Step: Hashable {
    case genres
    case languages
  }

  static let maxGenres = 5
  static let maxLanguages = 3

  @Published var path: [Step] = []
  @Published var selectedGenres: Set<String> = []
  @Published var selectedLanguages: Set<String> = []

  init() {
    selectedLanguages = [Self.deviceLanguageId()]

    #if DEBUG
    /// Jump straight into a step for previews/screenshots:
    /// SIMCTL_CHILD_BP_PREVIEW_STEP=genres|languages
    switch ProcessInfo.processInfo.environment["BP_PREVIEW_STEP"] {
    case "genres":
      path = [.genres]
    case "languages":
      path = [.genres, .languages]
    default:
      break
    }
    #endif
  }

  /// Defaults to the phone's language when we offer it, otherwise English
  static func deviceLanguageId() -> String {
    let deviceCode = Locale.preferredLanguages.first
      .flatMap { Locale(identifier: $0).language.languageCode?.identifier }

    if let deviceCode, OnboardingLanguage.all.contains(where: { $0.id == deviceCode }) {
      return deviceCode
    }
    return "en"
  }

  func isGenreSelected(_ genre: OnboardingGenre) -> Bool {
    selectedGenres.contains(genre.id)
  }

  func toggleGenre(_ genre: OnboardingGenre) {
    if selectedGenres.contains(genre.id) {
      selectedGenres.remove(genre.id)
    } else if selectedGenres.count < Self.maxGenres {
      selectedGenres.insert(genre.id)
    }
  }

  func isLanguageSelected(_ language: OnboardingLanguage) -> Bool {
    selectedLanguages.contains(language.id)
  }

  func toggleLanguage(_ language: OnboardingLanguage) {
    if selectedLanguages.contains(language.id) {
      selectedLanguages.remove(language.id)
    } else if selectedLanguages.count < Self.maxLanguages {
      selectedLanguages.insert(language.id)
    }
  }

  func persistPreferences() {
    let defaults = UserDefaults.standard
    defaults.set(Array(selectedGenres).sorted(), forKey: Constants.UserDefaults.onboardingSelectedGenres)
    defaults.set(Array(selectedLanguages).sorted(), forKey: Constants.UserDefaults.onboardingSelectedLanguages)
  }
}
