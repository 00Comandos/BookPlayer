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
/// through the "browse our catalog" route
struct CatalogHomeView: View {
  @Environment(\.accountService) private var accountService

  let onClose: () -> Void
  /// Files picked in the uploads page, forwarded to the import pipeline
  let onImportFiles: ([URL]) -> Void

  @StateObject private var session = CatalogSession()

  @State private var selectedGenreId: String?
  @State private var showProfile = false
  @State private var showPlayer = false
  @State private var showSearch = false
  @State private var showUploads = false
  @State private var navPath: [OnboardingGenre] = []
  /// Bumped when preferences change so the computed shelves re-read UserDefaults
  @State private var preferencesVersion = 0

  private let background = BPDesign.Colors.inkBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondary
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
    let baseCodes = Set(preferredLanguageIds.map { $0.split(separator: "-").first.map(String.init) ?? $0 })
    return CatalogMockLibrary.books.filter { book in
      baseCodes.isEmpty || baseCodes.contains(book.languageId)
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
    NavigationStack(path: $navPath) {
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
                genre: genre,
                count: CatalogMockLibrary.genreCount(genre.id),
                books: Array(languageMatches.filter { $0.genreId == selectedGenreId }.prefix(12))
              )
            } else {
              recentShelf

              if !forYou.isEmpty {
                shelf(title: Text("onboarding_catalog_title"), count: nil, books: forYou)
              }

              newContentShelf

              ForEach(orderedGenres) { genre in
                let books = Array(languageMatches.filter { $0.genreId == genre.id }.prefix(10))
                if !books.isEmpty {
                  shelf(genre: genre, count: CatalogMockLibrary.genreCount(genre.id), books: books)
                }
              }
            }
          }
          .padding(.bottom, 140)
        }

        bottomBar
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: OnboardingGenre.self) { genre in
        CatalogGenreListView(
          genre: genre,
          books: languageMatches.filter { $0.genreId == genre.id }
        )
      }
      .navigationDestination(isPresented: $showSearch) {
        CatalogSearchView(books: languageMatches)
      }
      .navigationDestination(isPresented: $showUploads) {
        UploadsView(style: .adaptive, title: "uploads_title_from_catalog") { urls in
          showUploads = false
          onImportFiles(urls)
        }
      }
    }
    .environmentObject(session)
    .sheet(
      isPresented: $session.showLogin,
      onDismiss: { session.handleLoginDismiss(hasAccount: accountService.hasAccount()) }
    ) {
      NavigationStack {
        LoginView()
      }
      .environmentObject(ThemeViewModel())
    }
    .sheet(isPresented: $showProfile, onDismiss: { preferencesVersion += 1 }) {
      CatalogProfileSheet(onGoLibrary: onClose, onImportFiles: onImportFiles)
        .environmentObject(session)
        .presentationDetents([.large])
    }
    .sheet(isPresented: $showPlayer) {
      CatalogPlayerView()
        .environmentObject(session)
    }
    .id(preferencesVersion)
    .onAppear {
      #if DEBUG
      if let genreId = ProcessInfo.processInfo.environment["BP_PREVIEW_GENRE"],
        let genre = OnboardingGenre.all.first(where: { $0.id == genreId })
      {
        navPath = [genre]
      }
      if ProcessInfo.processInfo.environment["BP_PREVIEW_SEARCH"] == "1" {
        showSearch = true
      }
      if ProcessInfo.processInfo.environment["BP_PREVIEW_UPLOADS"] == "1" {
        showUploads = true
      }
      if ProcessInfo.processInfo.environment["BP_PREVIEW_PROFILE"] == "1" {
        showProfile = true
      }
      if ProcessInfo.processInfo.environment["BP_PREVIEW_PLAYER"] == "1" {
        session.nowPlaying = languageMatches.first ?? CatalogMockLibrary.books.first
        showPlayer = true
      }
      if ProcessInfo.processInfo.environment["BP_PREVIEW_MINIPLAYER"] == "1" {
        session.nowPlaying = languageMatches.first ?? CatalogMockLibrary.books.first
      }
      #endif
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: Spacing.S2) {
      VStack(alignment: .leading, spacing: 2) {
        Text("catalog_home_title")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(BPDesign.Colors.textPrimary)

        Text(String(
          format: "catalog_home_books_format".localized,
          CatalogMockLibrary.formattedCount(CatalogMockLibrary.totalCount)
        ))
        .font(.system(size: 13))
        .foregroundStyle(subtle)
      }

      Spacer()

      Button {
        showUploads = true
      } label: {
        Image("lucide-upload")
          .resizable()
          .renderingMode(.template)
          .scaledToFit()
          .frame(width: 17, height: 17)
          .foregroundStyle(BPDesign.Colors.textPrimary)
          .frame(width: 34, height: 34)
          .background(elevated)
          .clipShape(Circle())
      }
      .accessibilityLabel(Text("catalog_home_upload_title"))

      Button {
        showProfile = true
      } label: {
        ZStack {
          Circle()
            .fill(accent.opacity(0.25))
          Image(systemName: "person.fill")
            .font(.system(size: 16))
            .foregroundStyle(accent)
        }
        .frame(width: 34, height: 34)
      }
      .accessibilityLabel(Text("profile_title"))
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
        .foregroundStyle(isSelected ? Color.black : BPDesign.Colors.textPrimary)
        .padding(.horizontal, Spacing.S1)
        .padding(.vertical, Spacing.S2)
        .background(isSelected ? accent : elevated)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  /// Up to 4 in-progress titles the user recently listened to,
  /// visually set apart on a subtly tinted surface
  @ViewBuilder
  private var recentShelf: some View {
    let recents = Array(session.recentBooks.prefix(4))
    if !recents.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.S1) {
        Text("catalog_home_recent")
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(BPDesign.Colors.textPrimary)
          .padding(.horizontal, Spacing.S)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: Spacing.S1) {
            ForEach(recents) { book in
              CatalogBookCard(book: book, showProgress: true)
            }
          }
          .padding(.horizontal, Spacing.S)
        }
      }
      .padding(.vertical, Spacing.S1)
      .background(
        RoundedRectangle(cornerRadius: BPDesign.Radius.banner)
          .fill(
            LinearGradient(
              colors: [accent.opacity(0.12), accent.opacity(0.03)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .padding(.horizontal, Spacing.S2)
    }
  }

  private var newContentShelf: some View {
    VStack(alignment: .leading, spacing: Spacing.S1) {
      Text("catalog_home_new_content")
        .font(.system(size: 19, weight: .bold))
        .foregroundStyle(BPDesign.Colors.textPrimary)
        .padding(.horizontal, Spacing.S)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: Spacing.S1) {
          ForEach(CatalogMockLibrary.newContent, id: \.book.id) { entry in
            CatalogBookCard(book: entry.book, uploadedBy: entry.uploadedBy)
          }
        }
        .padding(.horizontal, Spacing.S)
      }
    }
  }

  /// Shelf with a tappable header leading to the full category listing
  private func shelf(genre: OnboardingGenre, count: Int?, books: [CatalogBook]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S1) {
      Button {
        navPath.append(genre)
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.S2) {
          Text(genre.title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(BPDesign.Colors.textPrimary)

          if let count {
            Text(String(
              format: "catalog_home_books_format".localized,
              CatalogMockLibrary.formattedCount(count)
            ))
            .font(.system(size: 12))
            .foregroundStyle(subtle)
          }

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(subtle)
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal, Spacing.S)

      shelfRow(books: books)
    }
  }

  private func shelf(title: Text, count: Int?, books: [CatalogBook]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S1) {
      HStack(alignment: .firstTextBaseline, spacing: Spacing.S2) {
        title
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(BPDesign.Colors.textPrimary)

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

      shelfRow(books: books)
    }
  }

  private func shelfRow(books: [CatalogBook]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: Spacing.S1) {
        ForEach(books) { book in
          CatalogBookCard(book: book)
        }
      }
      .padding(.horizontal, Spacing.S)
    }
  }

  private var bottomBar: some View {
    HStack(alignment: .center, spacing: Spacing.S2) {
      if let book = session.nowPlaying {
        miniPlayer(book)
      } else {
        Spacer()
      }

      CatalogSearchButton {
        showSearch = true
      }
    }
    .padding(.horizontal, Spacing.S2)
    .padding(.bottom, Spacing.S2)
  }

  /// Tapping the info opens the full player; includes play/pause and a
  /// live progress bar with the remaining time
  private func miniPlayer(_ book: CatalogBook) -> some View {
    let progress = session.progress(for: book)
    let remaining = Int(Double(book.durationMinutes) * (1 - progress))

    return VStack(spacing: Spacing.S2) {
      HStack(spacing: Spacing.S1) {
        Button {
          showPlayer = true
        } label: {
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
                .foregroundStyle(BPDesign.Colors.textPrimary)
                .lineLimit(1)

              Text(verbatim: "-" + CatalogSession.formatMinutes(remaining))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(subtle)
            }

            Spacer()
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Button {
          session.isPaused.toggle()
        } label: {
          Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
            .font(.system(size: 20))
            .foregroundStyle(BPDesign.Colors.textPrimary)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Button {
          session.nowPlaying = nil
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(subtle)
            .frame(width: 28, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(subtle.opacity(0.25))
          Capsule()
            .fill(accent)
            .frame(width: geometry.size.width * progress)
        }
      }
      .frame(height: 3)
    }
    .padding(Spacing.S2)
    .background(elevated)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

#Preview {
  CatalogHomeView(onClose: {}, onImportFiles: { _ in })
}
