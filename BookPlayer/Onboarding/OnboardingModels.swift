//
//  OnboardingModels.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI

struct OnboardingGenre: Identifiable, Equatable {
  let id: String
  let systemImage: String

  var title: String { "onboarding_genre_\(id)".localized }

  static let all: [OnboardingGenre] = [
    .init(id: "fiction", systemImage: "books.vertical.fill"),
    .init(id: "mystery", systemImage: "magnifyingglass"),
    .init(id: "romance", systemImage: "heart.fill"),
    .init(id: "scifi", systemImage: "sparkles"),
    .init(id: "fantasy", systemImage: "wand.and.stars"),
    .init(id: "biography", systemImage: "person.fill"),
    .init(id: "history", systemImage: "building.columns.fill"),
    .init(id: "business", systemImage: "chart.line.uptrend.xyaxis"),
    .init(id: "selfhelp", systemImage: "figure.mind.and.body"),
    .init(id: "kids", systemImage: "teddybear.fill"),
    .init(id: "nonfiction", systemImage: "text.book.closed.fill"),
    .init(id: "poetry", systemImage: "quote.opening"),
  ]
}

struct OnboardingLanguage: Identifiable, Equatable {
  /// ISO 639-1 code, optionally with region/script (pt-BR, zh-Hans)
  let id: String
  let nativeName: String

  /// Primary language code, ignoring region/script
  var baseCode: String {
    id.split(separator: "-").first.map(String.init) ?? id
  }

  /// Every language the app UI is localized in
  static let all: [OnboardingLanguage] = [
    .init(id: "es", nativeName: "Español"),
    .init(id: "en", nativeName: "English"),
    .init(id: "pt-BR", nativeName: "Português (Brasil)"),
    .init(id: "pt-PT", nativeName: "Português (Portugal)"),
    .init(id: "fr", nativeName: "Français"),
    .init(id: "de", nativeName: "Deutsch"),
    .init(id: "it", nativeName: "Italiano"),
    .init(id: "ca", nativeName: "Català"),
    .init(id: "nl", nativeName: "Nederlands"),
    .init(id: "sv", nativeName: "Svenska"),
    .init(id: "da", nativeName: "Dansk"),
    .init(id: "nb", nativeName: "Norsk bokmål"),
    .init(id: "fi", nativeName: "Suomi"),
    .init(id: "pl", nativeName: "Polski"),
    .init(id: "cs", nativeName: "Čeština"),
    .init(id: "sk", nativeName: "Slovenčina"),
    .init(id: "hu", nativeName: "Magyar"),
    .init(id: "ro", nativeName: "Română"),
    .init(id: "ru", nativeName: "Русский"),
    .init(id: "uk", nativeName: "Українська"),
    .init(id: "el", nativeName: "Ελληνικά"),
    .init(id: "tr", nativeName: "Türkçe"),
    .init(id: "ar", nativeName: "العربية"),
    .init(id: "ja", nativeName: "日本語"),
    .init(id: "zh-Hans", nativeName: "中文（简体）"),
  ]
}

struct CatalogBook: Identifiable, Equatable {
  let id: String
  let title: String
  let author: String
  let genreId: String
  let languageId: String
  let durationMinutes: Int
  let coverHexes: [String]
  let coverSymbol: String

  var genre: OnboardingGenre? {
    OnboardingGenre.all.first(where: { $0.id == genreId })
  }

  var language: OnboardingLanguage? {
    OnboardingLanguage.all.first(where: { $0.id == languageId })
  }

  var durationDescription: String {
    let hours = durationMinutes / 60
    let minutes = durationMinutes % 60
    return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
  }

  var coverGradient: LinearGradient {
    LinearGradient(
      colors: coverHexes.map { Color(UIColor(hex: $0)) },
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  /// Sample catalog entries shown during onboarding until a real catalog service exists
  static let sampleCatalog: [CatalogBook] = [
    .init(id: "1", title: "La ciudad sumergida", author: "Elena Ríos", genreId: "fiction", languageId: "es", durationMinutes: 512, coverHexes: ["3B5BDB", "70A1FF"], coverSymbol: "building.2.fill"),
    .init(id: "2", title: "El faro del norte", author: "Marcos Deza", genreId: "mystery", languageId: "es", durationMinutes: 431, coverHexes: ["1E2A44", "4A6FA5"], coverSymbol: "moon.stars.fill"),
    .init(id: "3", title: "Cartas a medianoche", author: "Lucía Fontán", genreId: "romance", languageId: "es", durationMinutes: 367, coverHexes: ["C2255C", "FAA2C1"], coverSymbol: "heart.fill"),
    .init(id: "4", title: "Órbita cero", author: "D. Cabral", genreId: "scifi", languageId: "es", durationMinutes: 605, coverHexes: ["0B7285", "63E6BE"], coverSymbol: "sparkles"),
    .init(id: "5", title: "El reino de ceniza", author: "Ana Bosque", genreId: "fantasy", languageId: "es", durationMinutes: 745, coverHexes: ["5F3DC4", "B197FC"], coverSymbol: "wand.and.stars"),
    .init(id: "6", title: "Una vida en escena", author: "R. Palacios", genreId: "biography", languageId: "es", durationMinutes: 489, coverHexes: ["E8590C", "FFC078"], coverSymbol: "person.fill"),
    .init(id: "7", title: "Breve historia del mar", author: "J. Otero", genreId: "history", languageId: "es", durationMinutes: 528, coverHexes: ["2B8A3E", "8CE99A"], coverSymbol: "building.columns.fill"),
    .init(id: "8", title: "Hábitos que suman", author: "P. Iglesias", genreId: "selfhelp", languageId: "es", durationMinutes: 322, coverHexes: ["F08C00", "FFE066"], coverSymbol: "figure.mind.and.body"),
    .init(id: "9", title: "The Silent Harbor", author: "Kate Morrow", genreId: "mystery", languageId: "en", durationMinutes: 574, coverHexes: ["343A40", "868E96"], coverSymbol: "magnifyingglass"),
    .init(id: "10", title: "Starfall Protocol", author: "J. K. Ames", genreId: "scifi", languageId: "en", durationMinutes: 688, coverHexes: ["1864AB", "74C0FC"], coverSymbol: "sparkles"),
    .init(id: "11", title: "The Founder's Playbook", author: "Sam Delaney", genreId: "business", languageId: "en", durationMinutes: 402, coverHexes: ["087F5B", "63E6BE"], coverSymbol: "chart.line.uptrend.xyaxis"),
    .init(id: "12", title: "Winds of the Old Realm", author: "T. Everhart", genreId: "fantasy", languageId: "en", durationMinutes: 812, coverHexes: ["862E9C", "E599F7"], coverSymbol: "wand.and.stars"),
    .init(id: "13", title: "Little Cloud's Big Day", author: "Mia Tanner", genreId: "kids", languageId: "en", durationMinutes: 95, coverHexes: ["4DABF7", "FFD43B"], coverSymbol: "teddybear.fill"),
    .init(id: "14", title: "O jardim invisível", author: "C. Meireles", genreId: "fiction", languageId: "pt", durationMinutes: 456, coverHexes: ["099268", "96F2D7"], coverSymbol: "leaf.fill"),
    .init(id: "15", title: "Le dernier train", author: "H. Blanchet", genreId: "mystery", languageId: "fr", durationMinutes: 511, coverHexes: ["9C36B5", "EEBEFA"], coverSymbol: "tram.fill"),
    .init(id: "16", title: "Versos del alba", author: "M. Quintana", genreId: "poetry", languageId: "es", durationMinutes: 148, coverHexes: ["D6336C", "FCC2D7"], coverSymbol: "quote.opening"),
  ]
}
