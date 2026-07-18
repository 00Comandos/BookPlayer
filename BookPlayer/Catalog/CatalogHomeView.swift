//
//  CatalogHomeView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// Mock extended catalog: procedurally generated titles simulating a library
/// of hundreds of thousands of audiobooks across genres and languages
enum CatalogMockLibrary {
  static let totalCount = 384_216

  private static let titleParts: [String: (nouns: [String], suffixes: [String])] = [
    "es": (["El bosque", "La ciudad", "El viaje", "La memoria", "El faro", "La isla"],
           ["olvidado", "infinita", "de medianoche", "del norte", "secreto", "de cristal"]),
    "en": (["The Harbor", "The Garden", "The Journey", "The Archive", "The Lighthouse", "The Island"],
           ["of Silence", "at Midnight", "of Glass", "Untold", "of the North", "Reborn"]),
    "pt": (["O rio", "A floresta", "A viagem", "O segredo", "O farol", "A ilha"],
           ["esquecido", "infinita", "da meia-noite", "do norte", "de cristal", "perdida"]),
    "fr": (["Le jardin", "La ville", "Le voyage", "La mémoire", "Le phare", "L'île"],
           ["oublié", "infinie", "de minuit", "du nord", "secret", "de verre"]),
    "de": (["Der Wald", "Die Stadt", "Die Reise", "Das Archiv", "Der Leuchtturm", "Die Insel"],
           ["im Nebel", "bei Nacht", "aus Glas", "des Nordens", "der Stille", "ohne Namen"]),
    "it": (["Il bosco", "La città", "Il viaggio", "La memoria", "Il faro", "L'isola"],
           ["dimenticato", "infinita", "di mezzanotte", "del nord", "segreto", "di cristallo"]),
  ]

  private static let authors: [String: [String]] = [
    "es": ["Elena Ríos", "Marcos Deza", "Lucía Fontán", "A. Quintana", "P. Iglesias", "J. Otero"],
    "en": ["Kate Morrow", "J. K. Ames", "Sam Delaney", "T. Everhart", "Mia Tanner", "R. Ellison"],
    "pt": ["C. Meireles", "A. Barbosa", "L. Furtado", "M. Sales", "R. Antunes", "T. Peixoto"],
    "fr": ["H. Blanchet", "C. Morel", "É. Vasseur", "L. Perrin", "A. Chastain", "M. Roux"],
    "de": ["K. Brandt", "L. Hoffmann", "S. Weber", "A. Neumann", "J. Falk", "M. Richter"],
    "it": ["G. Ferraro", "L. Moretti", "S. Bellini", "A. Conti", "P. Ricci", "V. Serra"],
  ]

  private static let coverPalettes: [[String]] = [
    ["3B5BDB", "70A1FF"], ["C2255C", "FAA2C1"], ["0B7285", "63E6BE"],
    ["5F3DC4", "B197FC"], ["E8590C", "FFC078"], ["2B8A3E", "8CE99A"],
    ["F08C00", "FFE066"], ["1864AB", "74C0FC"], ["862E9C", "E599F7"],
    ["087F5B", "63E6BE"], ["9C36B5", "EEBEFA"], ["D6336C", "FCC2D7"],
  ]

  private static let uploaderNames = ["María G.", "Carlos R.", "Ana P.", "Luis M.", "Sofía T."]

  /// Deterministic pseudo-count per genre, in the tens of thousands
  static func genreCount(_ genreId: String) -> Int {
    let seed = genreId.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }
    return 8_000 + abs(seed) % 72_000
  }

  static func formattedCount(_ count: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
  }

  static let books: [CatalogBook] = {
    var result: [CatalogBook] = []
    for (genreIndex, genre) in OnboardingGenre.all.enumerated() {
      for language in OnboardingLanguage.all {
        guard let parts = titleParts[language.id], let names = authors[language.id] else { continue }
        for volume in 0..<6 {
          let seed = genreIndex &* 13 &+ volume &* 7 &+ language.id.count
          let noun = parts.nouns[(seed + volume) % parts.nouns.count]
          let suffix = parts.suffixes[(seed + genreIndex) % parts.suffixes.count]
          let palette = coverPalettes[(seed + volume + genreIndex) % coverPalettes.count]
          result.append(
            CatalogBook(
              id: "\(genre.id)-\(language.id)-\(volume)",
              title: "\(noun) \(suffix)",
              author: names[(seed + volume) % names.count],
              genreId: genre.id,
              languageId: language.id,
              durationMinutes: 180 + (seed % 12) * 55,
              coverHexes: palette,
              coverSymbol: genre.systemImage
            )
          )
        }
      }
    }
    return result
  }()

  /// Fresh arrivals: a mix of editorial picks and user-uploaded content
  static let newContent: [(book: CatalogBook, uploadedBy: String?)] = {
    let picks = books.enumerated().filter { $0.offset % 17 == 3 }.prefix(10)
    return picks.enumerated().map { index, entry in
      (entry.element, index % 2 == 1 ? uploaderNames[index % uploaderNames.count] : nil)
    }
  }()
}

/// Spotify-style catalog browser shown after finishing the onboarding
/// through the "browse our catalog" route. Playing a book requires an
/// account: the login flow is presented first and playback starts once
/// it completes.
struct CatalogHomeView: View {
  @Environment(\.accountService) private var accountService

  let onClose: () -> Void
  let onUploadOwn: () -> Void

  @State private var selectedGenreId: String?
  @State private var nowPlaying: CatalogBook?
  @State private var pendingBook: CatalogBook?
  @State private var showLogin = false

  private let background = BPDesign.Colors.mediaBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  private var preferredGenreIds: [String] {
    UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.onboardingSelectedGenres) ?? []
  }

  private var preferredLanguageIds: [String] {
    UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.onboardingSelectedLanguages) ?? []
  }

  /// User-selected genres first, then the rest of the catalog categories
  private var orderedGenres: [OnboardingGenre] {
    let preferred = OnboardingGenre.all.filter { preferredGenreIds.contains($0.id) }
    let rest = OnboardingGenre.all.filter { !preferredGenreIds.contains($0.id) }
    return preferred + rest
  }

  private var languageMatches: [CatalogBook] {
    CatalogMockLibrary.books.filter { book in
      preferredLanguageIds.isEmpty || preferredLanguageIds.contains(book.languageId)
    }
  }

  private var forYou: [CatalogBook] {
    Array(
      languageMatches
        .filter { preferredGenreIds.contains($0.genreId) }
        .prefix(10)
    )
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.M) {
          header
          chips

          if let selectedGenreId,
            let genre = OnboardingGenre.all.first(where: { $0.id == selectedGenreId })
          {
            shelf(
              title: Text(genre.title),
              count: CatalogMockLibrary.genreCount(genre.id),
              books: Array(languageMatches.filter { $0.genreId == selectedGenreId }.prefix(12))
            )
          } else {
            if !forYou.isEmpty {
              shelf(title: Text("onboarding_catalog_title"), count: nil, books: forYou)
            }

            newContentShelf
            uploadBanner

            ForEach(orderedGenres) { genre in
              let books = Array(languageMatches.filter { $0.genreId == genre.id }.prefix(10))
              if !books.isEmpty {
                shelf(
                  title: Text(genre.title),
                  count: CatalogMockLibrary.genreCount(genre.id),
                  books: books
                )
              }
            }
          }
        }
        .padding(.bottom, 120)
      }

      if let book = nowPlaying {
        miniPlayer(book)
      }
    }
    .sheet(isPresented: $showLogin, onDismiss: handleLoginDismiss) {
      NavigationStack {
        LoginView()
      }
      .environmentObject(ThemeViewModel())
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 2) {
        Text("catalog_home_title")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(.white)

        Text(String(
          format: "catalog_home_books_format".localized,
          CatalogMockLibrary.formattedCount(CatalogMockLibrary.totalCount)
        ))
        .font(.system(size: 13))
        .foregroundStyle(subtle)
      }

      Spacer()

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(elevated)
          .clipShape(Circle())
      }
      .accessibilityLabel(Text("onboarding_go_library"))
    }
    .padding(.horizontal, Spacing.S)
    .padding(.top, Spacing.S)
  }

  private var chips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Spacing.S2) {
        chip(title: Text("catalog_home_all"), isSelected: selectedGenreId == nil) {
          selectedGenreId = nil
        }
        ForEach(orderedGenres) { genre in
          chip(title: Text(genre.title), isSelected: selectedGenreId == genre.id) {
            selectedGenreId = selectedGenreId == genre.id ? nil : genre.id
          }
        }
      }
      .padding(.horizontal, Spacing.S)
    }
  }

  private func chip(title: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      title
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(isSelected ? .black : .white)
        .padding(.horizontal, Spacing.S1)
        .padding(.vertical, Spacing.S2)
        .background(isSelected ? accent : elevated)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var newContentShelf: some View {
    VStack(alignment: .leading, spacing: Spacing.S1) {
      Text("catalog_home_new_content")
        .font(.system(size: 19, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.S)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: Spacing.S1) {
          ForEach(CatalogMockLibrary.newContent, id: \.book.id) { entry in
            bookCard(entry.book, uploadedBy: entry.uploadedBy)
          }
        }
        .padding(.horizontal, Spacing.S)
      }
    }
  }

  private var uploadBanner: some View {
    Button(action: onUploadOwn) {
      HStack(spacing: Spacing.S1) {
        Image("lucide-upload")
          .resizable()
          .renderingMode(.template)
          .scaledToFit()
          .frame(width: 22, height: 22)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(accent)
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text("catalog_home_upload_title")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)

          Text("onboarding_import_option_description")
            .font(.system(size: 12))
            .foregroundStyle(subtle)
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(subtle)
      }
      .padding(Spacing.S1)
      .background(elevated)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, Spacing.S)
    }
    .buttonStyle(.plain)
  }

  private func shelf(title: Text, count: Int?, books: [CatalogBook]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S1) {
      HStack(alignment: .firstTextBaseline, spacing: Spacing.S2) {
        title
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(.white)

        if let count {
          Text(String(
            format: "catalog_home_books_format".localized,
            CatalogMockLibrary.formattedCount(count)
          ))
          .font(.system(size: 12))
          .foregroundStyle(subtle)
        }
      }
      .padding(.horizontal, Spacing.S)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: Spacing.S1) {
          ForEach(books) { book in
            bookCard(book, uploadedBy: nil)
          }
        }
        .padding(.horizontal, Spacing.S)
      }
    }
  }

  private func bookCard(_ book: CatalogBook, uploadedBy: String?) -> some View {
    Button {
      handlePlay(book)
    } label: {
      VStack(alignment: .leading, spacing: Spacing.S2) {
        RoundedRectangle(cornerRadius: 6)
          .fill(book.coverGradient)
          .frame(width: 140, height: 140)
          .overlay(
            Image(systemName: book.coverSymbol)
              .font(.system(size: 40))
              .foregroundStyle(.white.opacity(0.9))
          )
          .overlay(alignment: .bottomTrailing) {
            if nowPlaying == book {
              Image(systemName: "waveform.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white, .black.opacity(0.45))
                .padding(Spacing.S3)
            }
          }

        Text(book.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        if let uploadedBy {
          Text(String(format: "catalog_home_uploaded_by".localized, uploadedBy))
            .font(.system(size: 12))
            .foregroundStyle(accent)
            .lineLimit(1)
        } else {
          Text(book.author)
            .font(.system(size: 12))
            .foregroundStyle(subtle)
            .lineLimit(1)
        }
      }
      .frame(width: 140, alignment: .leading)
    }
    .buttonStyle(.plain)
  }

  private func miniPlayer(_ book: CatalogBook) -> some View {
    HStack(spacing: Spacing.S1) {
      RoundedRectangle(cornerRadius: 4)
        .fill(book.coverGradient)
        .frame(width: 40, height: 40)
        .overlay(
          Image(systemName: "waveform")
            .font(.system(size: 16))
            .foregroundStyle(.white)
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(book.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        Text("onboarding_playing_demo")
          .font(.system(size: 12))
          .foregroundStyle(subtle)
      }

      Spacer()

      Button {
        nowPlaying = nil
      } label: {
        Image(systemName: "stop.fill")
          .font(.system(size: 18))
          .foregroundStyle(.white)
      }
      .padding(.trailing, Spacing.S3)
    }
    .padding(Spacing.S2)
    .background(elevated)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.horizontal, Spacing.S2)
    .padding(.bottom, Spacing.S2)
  }

  /// JTBD: play the first catalog book — requires login before playback
  private func handlePlay(_ book: CatalogBook) {
    if accountService.hasAccount() {
      nowPlaying = book
    } else {
      pendingBook = book
      showLogin = true
    }
  }

  private func handleLoginDismiss() {
    guard let book = pendingBook else { return }
    pendingBook = nil

    if accountService.hasAccount() {
      nowPlaying = book
    }
  }
}

#Preview {
  CatalogHomeView(onClose: {}, onUploadOwn: {})
}
