//
//  CatalogBrowseViews.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UniformTypeIdentifiers

/// Shared playback/session state for the catalog browsing experience:
/// current preview, pending login-gated book and recently listened titles
@MainActor
final class CatalogSession: ObservableObject {
  @Published var nowPlaying: CatalogBook? {
    didSet {
      if let nowPlaying {
        recordRecent(nowPlaying)
      }
    }
  }
  @Published var pendingBook: CatalogBook?
  @Published var showLogin = false
  @Published var isPaused = false
  @Published private(set) var recentIds: [String]

  init() {
    recentIds = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.catalogRecentlyPlayed) ?? []
  }

  var recentBooks: [CatalogBook] {
    recentIds.compactMap { id in
      CatalogMockLibrary.books.first { $0.id == id }
    }
  }

  /// JTBD: playing requires an account; the login flow runs first and
  /// playback starts once it completes
  func requestPlay(_ book: CatalogBook, hasAccount: Bool) {
    if hasAccount {
      nowPlaying = book
    } else {
      pendingBook = book
      showLogin = true
    }
  }

  func handleLoginDismiss(hasAccount: Bool) {
    guard let book = pendingBook else { return }
    pendingBook = nil

    if hasAccount {
      nowPlaying = book
    }
  }

  /// Mock in-progress position, deterministic per book
  func progress(for book: CatalogBook) -> Double {
    let seed = book.id.unicodeScalars.reduce(11) { $0 &* 17 &+ Int($1.value) }
    return 0.2 + Double(abs(seed) % 60) / 100.0
  }

  /// Mock listening time in minutes, growing with actual usage of the catalog
  var listeningStats: (day: Int, week: Int, month: Int, year: Int) {
    let base = recentIds.count
    return (
      day: 38 + base * 9,
      week: 260 + base * 22,
      month: 1_180 + base * 40,
      year: 9_400 + base * 90
    )
  }

  static func formatMinutes(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    return hours > 0 ? "\(hours) h \(mins) m" : "\(mins) m"
  }

  private func recordRecent(_ book: CatalogBook) {
    var ids = recentIds.filter { $0 != book.id }
    ids.insert(book.id, at: 0)
    recentIds = Array(ids.prefix(8))
    UserDefaults.standard.set(recentIds, forKey: Constants.UserDefaults.catalogRecentlyPlayed)
  }
}

/// Cover + title card shared by home shelves, genre pages and search results
struct CatalogBookCard: View {
  @EnvironmentObject private var session: CatalogSession
  @Environment(\.accountService) private var accountService

  let book: CatalogBook
  var uploadedBy: String?
  /// Fixed width for shelves; nil stretches to fill grid cells
  var width: CGFloat? = 140
  var showProgress = false

  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  var body: some View {
    Button {
      session.requestPlay(book, hasAccount: accountService.hasAccount())
    } label: {
      VStack(alignment: .leading, spacing: Spacing.S2) {
        cover

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
      .frame(width: width, alignment: .leading)
    }
    .buttonStyle(.plain)
  }

  private var cover: some View {
    RoundedRectangle(cornerRadius: BPDesign.Radius.cover)
      .fill(book.coverGradient)
      .frame(width: width, height: width)
      .aspectRatio(width == nil ? 1 : nil, contentMode: .fit)
      .overlay(
        Image(systemName: book.coverSymbol)
          .font(.system(size: 40))
          .foregroundStyle(.white.opacity(0.9))
      )
      .overlay(alignment: .bottomTrailing) {
        if session.nowPlaying == book {
          Image(systemName: "waveform.circle.fill")
            .font(.system(size: 26))
            .foregroundStyle(.white, .black.opacity(0.45))
            .padding(Spacing.S3)
        }
      }
      .overlay(alignment: .bottom) {
        if showProgress {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.3))
              Capsule()
                .fill(accent)
                .frame(width: geometry.size.width * session.progress(for: book))
            }
          }
          .frame(height: 4)
          .padding(.horizontal, Spacing.S2)
          .padding(.bottom, Spacing.S2)
        }
      }
  }
}

/// Full listing of one category, reached by tapping a shelf title
struct CatalogGenreListView: View {
  @EnvironmentObject private var session: CatalogSession

  let genre: OnboardingGenre
  let books: [CatalogBook]

  @State private var showSearch = false

  private let background = BPDesign.Colors.mediaBackground
  private let subtle = BPDesign.Colors.textSecondaryMedia

  private let columns = [
    GridItem(.flexible(), spacing: Spacing.S1),
    GridItem(.flexible(), spacing: Spacing.S1),
  ]

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          Text(genre.title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)

          Text(String(
            format: "catalog_home_books_format".localized,
            CatalogMockLibrary.formattedCount(CatalogMockLibrary.genreCount(genre.id))
          ))
          .font(.system(size: 13))
          .foregroundStyle(subtle)

          LazyVGrid(columns: columns, spacing: Spacing.S) {
            ForEach(books) { book in
              CatalogBookCard(book: book, width: nil)
            }
          }
          .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.S)
        .padding(.bottom, 120)
      }

      CatalogSearchButton {
        showSearch = true
      }
      .padding(.trailing, Spacing.S)
      .padding(.bottom, Spacing.S)
    }
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbarBackground(background, for: .navigationBar)
    .navigationDestination(isPresented: $showSearch) {
      CatalogSearchView(books: books, scope: genre)
    }
  }
}

/// Search across the catalog (or scoped to one category)
struct CatalogSearchView: View {
  let books: [CatalogBook]
  var scope: OnboardingGenre?

  @State private var query = ""
  @FocusState private var isFocused: Bool

  private let background = BPDesign.Colors.mediaBackground
  private let elevated = BPDesign.Colors.mediaSurfaceElevated
  private let subtle = BPDesign.Colors.textSecondaryMedia

  private let columns = [
    GridItem(.flexible(), spacing: Spacing.S1),
    GridItem(.flexible(), spacing: Spacing.S1),
  ]

  private var results: [CatalogBook] {
    guard !query.isEmpty else { return [] }
    return books.filter {
      $0.title.localizedCaseInsensitiveContains(query)
        || $0.author.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      VStack(alignment: .leading, spacing: Spacing.S1) {
        searchField

        if let scope {
          Text(scope.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(subtle)
        }

        if query.isEmpty {
          Spacer()
        } else if results.isEmpty {
          Text("catalog_home_no_results")
            .font(.system(size: 15))
            .foregroundStyle(subtle)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.L)
          Spacer()
        } else {
          ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.S) {
              ForEach(results) { book in
                CatalogBookCard(book: book, width: nil)
              }
            }
            .padding(.bottom, 120)
          }
        }
      }
      .padding(.horizontal, Spacing.S)
      .padding(.top, Spacing.S2)
    }
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbarBackground(background, for: .navigationBar)
    .onAppear { isFocused = true }
  }

  private var searchField: some View {
    HStack(spacing: Spacing.S2) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 15))
        .foregroundStyle(subtle)

      TextField(
        "",
        text: $query,
        prompt: Text("catalog_home_search_placeholder").foregroundStyle(subtle)
      )
      .font(.system(size: 15))
      .foregroundStyle(.white)
      .focused($isFocused)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)

      if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 15))
            .foregroundStyle(subtle)
        }
      }
    }
    .padding(.horizontal, Spacing.S1)
    .frame(height: 42)
    .background(elevated)
    .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
  }
}

/// Floating circular search trigger, echoing the app's navbar search pill
struct CatalogSearchButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(BPDesign.Colors.mediaSurfaceElevated)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    .accessibilityLabel(Text("catalog_home_search_placeholder"))
  }
}

/// Minimal upload page in the new visual language, reached from Discover
/// ("Your uploads", with a return to the catalog) or right after choosing
/// "Load my audiobooks" in the onboarding ("My audiobooks"). One single
/// action: pick files, which flow into the existing import pipeline.
struct UploadsView: View {
  enum Style {
    /// Fixed dark, for the always-dark catalog context
    case media
    /// Follows the phone appearance, for the standalone context
    case adaptive
  }

  let style: Style
  let title: LocalizedStringKey
  var showsClose = false
  let onPick: ([URL]) -> Void
  var onClose: (() -> Void)?

  @State private var showPicker = false

  private var background: Color {
    style == .media ? BPDesign.Colors.mediaBackground : BPDesign.Colors.inkBackground
  }

  private var primaryText: Color {
    style == .media ? .white : BPDesign.Colors.textPrimary
  }

  private var secondaryText: Color {
    style == .media ? BPDesign.Colors.textSecondaryMedia : BPDesign.Colors.textSecondary
  }

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      VStack(spacing: Spacing.S1) {
        Spacer()

        ZStack {
          Circle().fill(BPDesign.Colors.coral.opacity(0.18))
          Image("lucide-upload")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 34, height: 34)
            .foregroundStyle(BPDesign.Colors.coral)
        }
        .frame(width: 92, height: 92)
        .padding(.bottom, Spacing.S)

        Text(title)
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(primaryText)
          .multilineTextAlignment(.center)

        Text("uploads_empty_description")
          .font(.system(size: 15))
          .foregroundStyle(secondaryText)
          .multilineTextAlignment(.center)
          .padding(.horizontal, Spacing.L)

        Spacer()

        BPPrimaryButton(title: "uploads_choose_files", isEnabled: true) {
          showPicker = true
        }
        .padding(.horizontal, Spacing.M)
        .padding(.bottom, Spacing.S)
      }
    }
    .toolbar {
      if showsClose {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            onClose?()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(primaryText)
          }
        }
      }
    }
    .toolbarColorScheme(style == .media ? .dark : nil, for: .navigationBar)
    .sheet(isPresented: $showPicker) {
      AudioDocumentPicker { urls in
        showPicker = false
        onPick(urls)
      }
      .ignoresSafeArea()
    }
  }
}

/// System document picker for audio files, folders and zips
struct AudioDocumentPicker: UIViewControllerRepresentable {
  let onPick: ([URL]) -> Void

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.audio, .folder, .zip],
      asCopy: true
    )
    picker.allowsMultipleSelection = true
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onPick: onPick)
  }

  final class Coordinator: NSObject, UIDocumentPickerDelegate {
    let onPick: ([URL]) -> Void

    init(onPick: @escaping ([URL]) -> Void) {
      self.onPick = onPick
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      onPick(urls)
    }
  }
}

/// Flowing chip layout that hugs each chip's content width
struct WrapLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

/// Avatar sheet: profile info, listening stats and interests editing.
/// Interest changes persist immediately — no save button needed.
struct CatalogProfileSheet: View {
  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var session: CatalogSession
  @Environment(\.dismiss) private var dismiss

  let onGoLibrary: () -> Void

  @State private var showLogin = false
  @State private var selectedGenres: Set<String>
  @State private var selectedLanguages: Set<String>

  private let background = BPDesign.Colors.mediaBackground
  private let elevated = BPDesign.Colors.mediaSurfaceElevated
  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  init(onGoLibrary: @escaping () -> Void) {
    self.onGoLibrary = onGoLibrary
    let defaults = UserDefaults.standard
    _selectedGenres = State(initialValue: Set(
      defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedGenres) ?? []
    ))
    _selectedLanguages = State(initialValue: Set(
      defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedLanguages) ?? []
    ))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.S1) {
        identityHeader
        statsSection

        interestsSection(
          title: "catalog_home_genres_section",
          count: selectedGenres.count,
          limit: OnboardingViewModel.maxGenres
        ) {
          ForEach(OnboardingGenre.all) { genre in
            chip(title: genre.title, isSelected: selectedGenres.contains(genre.id)) {
              toggle(genre.id, in: &selectedGenres, limit: OnboardingViewModel.maxGenres)
            }
          }
        }

        interestsSection(
          title: "catalog_home_languages_section",
          count: selectedLanguages.count,
          limit: OnboardingViewModel.maxLanguages
        ) {
          ForEach(OnboardingLanguage.all) { language in
            chip(title: language.nativeName, isSelected: selectedLanguages.contains(language.id)) {
              toggle(language.id, in: &selectedLanguages, limit: OnboardingViewModel.maxLanguages)
            }
          }
        }

        Button {
          dismiss()
          onGoLibrary()
        } label: {
          Text("onboarding_go_library")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(elevated)
            .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.button))
        }
        .padding(.top, Spacing.S)
      }
      .padding(.horizontal, Spacing.M)
      .padding(.top, Spacing.M)
      .padding(.bottom, Spacing.L)
    }
    .background(background.ignoresSafeArea())
    .sheet(isPresented: $showLogin) {
      NavigationStack {
        LoginView()
      }
      .environmentObject(ThemeViewModel())
    }
  }

  private var identityHeader: some View {
    HStack(spacing: Spacing.S1) {
      ZStack {
        Circle().fill(accent.opacity(0.25))
        Image(systemName: "person.fill")
          .font(.system(size: 24))
          .foregroundStyle(accent)
      }
      .frame(width: 56, height: 56)

      VStack(alignment: .leading, spacing: 2) {
        if accountService.hasAccount() {
          Text(accountService.account.email)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
        } else {
          Text("catalog_home_profile_guest")
            .font(.system(size: 15))
            .foregroundStyle(subtle)

          Button {
            showLogin = true
          } label: {
            Text("catalog_home_profile_login")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(accent)
          }
        }
      }

      Spacer()
    }
  }

  private var statsSection: some View {
    VStack(alignment: .leading, spacing: Spacing.S2) {
      Text("profile_stats_title")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(subtle)
        .padding(.top, Spacing.S)

      let stats = session.listeningStats
      let tiles: [(LocalizedStringKey, Int)] = [
        ("profile_stats_day", stats.day),
        ("profile_stats_week", stats.week),
        ("profile_stats_month", stats.month),
        ("profile_stats_year", stats.year),
      ]

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: Spacing.S2),
          GridItem(.flexible(), spacing: Spacing.S2),
        ],
        spacing: Spacing.S2
      ) {
        ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
          VStack(alignment: .leading, spacing: 2) {
            Text(CatalogSession.formatMinutes(tile.1))
              .font(.system(size: 19, weight: .bold))
              .foregroundStyle(.white)
            Text(tile.0)
              .font(.system(size: 12))
              .foregroundStyle(subtle)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Spacing.S1)
          .background(elevated)
          .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
        }
      }
    }
  }

  private func interestsSection<Content: View>(
    title: LocalizedStringKey,
    count: Int,
    limit: Int,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S2) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(subtle)

        Spacer()

        Text("\(count)/\(limit)")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(subtle)
      }
      .padding(.top, Spacing.S)

      WrapLayout(spacing: Spacing.S2) {
        content()
      }
    }
  }

  private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: Spacing.S3) {
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
        }
        Text(title)
          .font(.system(size: 13, weight: .medium))
      }
      .foregroundStyle(isSelected ? .black : .white)
      .padding(.horizontal, Spacing.S1)
      .frame(height: 34)
      .background(isSelected ? accent : Color.clear)
      .overlay(
        Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }

  private func toggle(_ id: String, in set: inout Set<String>, limit: Int) {
    if set.contains(id) {
      set.remove(id)
    } else if set.count < limit {
      set.insert(id)
    }
    persist()
  }

  private func persist() {
    let defaults = UserDefaults.standard
    defaults.set(Array(selectedGenres).sorted(), forKey: Constants.UserDefaults.onboardingSelectedGenres)
    defaults.set(Array(selectedLanguages).sorted(), forKey: Constants.UserDefaults.onboardingSelectedLanguages)
  }
}

/// Full-screen mock player for catalog previews, opened from the mini-player.
/// Once real catalog audio exists this hands off to the app's PlayerManager.
struct CatalogPlayerView: View {
  @EnvironmentObject private var session: CatalogSession
  @Environment(\.dismiss) private var dismiss

  private let background = BPDesign.Colors.mediaBackground
  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      if let book = session.nowPlaying {
        VStack(spacing: Spacing.S1) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.down")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(subtle)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, Spacing.S)

          Spacer()

          RoundedRectangle(cornerRadius: 16)
            .fill(book.coverGradient)
            .frame(width: 280, height: 280)
            .overlay(
              Image(systemName: book.coverSymbol)
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.9))
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)

          VStack(spacing: 4) {
            Text(book.title)
              .font(.system(size: 21, weight: .bold))
              .foregroundStyle(.white)
              .multilineTextAlignment(.center)

            Text(book.author)
              .font(.system(size: 15))
              .foregroundStyle(subtle)
          }
          .padding(.top, Spacing.S)

          progressBar(for: book)
            .padding(.top, Spacing.S)

          HStack(spacing: Spacing.L) {
            Image(systemName: "gobackward.15")
              .font(.system(size: 28))
              .foregroundStyle(.white)

            Button {
              session.isPaused.toggle()
            } label: {
              ZStack {
                Circle().fill(accent)
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                  .font(.system(size: 28))
                  .foregroundStyle(.white)
              }
              .frame(width: 72, height: 72)
            }

            Image(systemName: "goforward.15")
              .font(.system(size: 28))
              .foregroundStyle(.white)
          }
          .padding(.top, Spacing.S)

          Text("onboarding_playing_demo")
            .font(.system(size: 12))
            .foregroundStyle(subtle)
            .padding(.top, Spacing.S)

          Spacer()
        }
        .padding(.horizontal, Spacing.M)
      }
    }
  }

  private func progressBar(for book: CatalogBook) -> some View {
    let progress = session.progress(for: book)
    let elapsed = Int(Double(book.durationMinutes) * progress)

    return VStack(spacing: Spacing.S3) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.2))
          Capsule()
            .fill(accent)
            .frame(width: geometry.size.width * progress)
        }
      }
      .frame(height: 4)

      HStack {
        Text(CatalogSession.formatMinutes(elapsed))
        Spacer()
        Text(CatalogSession.formatMinutes(book.durationMinutes))
      }
      .font(.system(size: 12))
      .foregroundStyle(subtle)
    }
  }
}
