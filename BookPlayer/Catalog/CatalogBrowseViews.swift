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

  @Published private(set) var progressOverrides: [String: Double] = [:]

  /// Mock in-progress position: deterministic per book until the user
  /// jumps somewhere (e.g. picking a chapter)
  func progress(for book: CatalogBook) -> Double {
    if let override = progressOverrides[book.id] {
      return override
    }
    let seed = book.id.unicodeScalars.reduce(11) { $0 &* 17 &+ Int($1.value) }
    return 0.2 + Double(abs(seed) % 60) / 100.0
  }

  func setProgress(_ fraction: Double, for book: CatalogBook) {
    progressOverrides[book.id] = min(max(fraction, 0), 1)
  }

  struct Chapter: Identifiable {
    let id: Int
    let startFraction: Double
    let startMinutes: Int
  }

  /// Evenly spaced mock chapters derived from the book duration
  func chapters(for book: CatalogBook) -> [Chapter] {
    let count = max(3, min(12, book.durationMinutes / 50))
    return (0..<count).map { index in
      let fraction = Double(index) / Double(count)
      return Chapter(
        id: index + 1,
        startFraction: fraction,
        startMinutes: Int(Double(book.durationMinutes) * fraction)
      )
    }
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
  /// Set in always-dark contexts (player, about sheet) so text stays white
  var forceDark = false

  private let accent = BPDesign.Colors.coral

  private var titleColor: Color {
    forceDark ? .white : BPDesign.Colors.textPrimary
  }

  private var subtle: Color {
    forceDark ? BPDesign.Colors.textSecondaryMedia : BPDesign.Colors.textSecondary
  }

  var body: some View {
    Button {
      session.requestPlay(book, hasAccount: accountService.hasAccount())
    } label: {
      VStack(alignment: .leading, spacing: Spacing.S2) {
        cover

        Text(book.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(titleColor)
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

  private let background = BPDesign.Colors.inkBackground
  private let subtle = BPDesign.Colors.textSecondary

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
            .foregroundStyle(BPDesign.Colors.textPrimary)

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

  private let background = BPDesign.Colors.inkBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondary

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
      .foregroundStyle(BPDesign.Colors.textPrimary)
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
        .foregroundStyle(BPDesign.Colors.textPrimary)
        .frame(width: 52, height: 52)
        .background(BPDesign.Colors.surfaceElevated)
        .clipShape(Circle())
        .overlay(Circle().stroke(BPDesign.Border.hairlineColor, lineWidth: 1))
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

/// Avatar sheet: a tidy option menu (stats, interests, subscription,
/// settings, library) with identity, login and logout
struct CatalogProfileSheet: View {
  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var session: CatalogSession
  @Environment(\.dismiss) private var dismiss

  let onGoLibrary: () -> Void

  enum Destination: Hashable {
    case stats
    case interests
    case subscription
    case library
  }

  /// Files picked in the library empty state, forwarded to the import pipeline
  var onImportFiles: ([URL]) -> Void = { _ in }

  @State private var path: [Destination] = []
  @State private var showLogin = false
  @State private var showSettings = false
  /// Bumped after login/logout so the identity re-renders
  @State private var accountVersion = 0

  private let background = BPDesign.Colors.inkBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondary
  private let accent = BPDesign.Colors.coral

  private var planName: LocalizedStringKey {
    switch accountService.accessLevel {
    case .plus: return "BookPlayer Plus"
    case .pro: return "BookPlayer Pro"
    default: return "profile_plan_free"
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S2) {
          identityHeader
            .padding(.bottom, Spacing.S2)

          menuRow(icon: "chart.bar.fill", title: Text("profile_stats_title")) {
            path.append(.stats)
          }
          menuRow(icon: "slider.horizontal.3", title: Text("catalog_home_interests_title")) {
            path.append(.interests)
          }
          menuRow(
            icon: "crown.fill",
            title: Text("profile_menu_subscription"),
            badge: Text(planName)
          ) {
            path.append(.subscription)
          }
          menuRow(icon: "gearshape.fill", title: Text("settings_title")) {
            showSettings = true
          }
          menuRow(icon: "books.vertical.fill", title: Text("catalog_library_title")) {
            path.append(.library)
          }

          appearanceSelector
            .padding(.top, Spacing.S)

          if accountService.hasAccount() {
            Button {
              try? accountService.logout()
              accountVersion += 1
            } label: {
              Text("profile_logout")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(UIColor.systemRed))
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(elevated)
                .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.S)
          }
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.M)
        .padding(.bottom, Spacing.L)
      }
      .background(background.ignoresSafeArea())
      .navigationDestination(for: Destination.self) { destination in
        Group {
          switch destination {
          case .stats:
            statsPage
          case .interests:
            CatalogInterestsPage()
          case .subscription:
            CatalogSubscriptionPage(planName: planName)
          case .library:
            CatalogLibraryView(
              onImportFiles: onImportFiles,
              onOpenFull: {
                dismiss()
                onGoLibrary()
              }
            )
          }
        }
            .toolbarBackground(background, for: .navigationBar)
      }
    }
    .id(accountVersion)
    .onAppear {
      #if DEBUG
      if ProcessInfo.processInfo.environment["BP_PREVIEW_LIBRARY"] == "1" {
        path = [.library]
      }
      #endif
    }
    .sheet(isPresented: $showLogin, onDismiss: { accountVersion += 1 }) {
      NavigationStack {
        LoginView()
      }
      .environmentObject(ThemeViewModel())
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .environmentObject(ThemeViewModel())
    }
  }

  private enum AppearanceMode: CaseIterable {
    case system, light, dark

    var label: LocalizedStringKey {
      switch self {
      case .system: return "profile_appearance_system"
      case .light: return "profile_appearance_light"
      case .dark: return "profile_appearance_dark"
      }
    }
  }

  private var currentAppearance: AppearanceMode {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled) {
      return .system
    }
    return defaults.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled) ? .dark : .light
  }

  /// Light/dark/system switch, wired to the app's existing theme engine
  private var appearanceSelector: some View {
    VStack(alignment: .leading, spacing: Spacing.S2) {
      Text("profile_appearance_title")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(subtle)

      HStack(spacing: Spacing.S2) {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
          Button {
            apply(mode)
          } label: {
            Text(mode.label)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(currentAppearance == mode ? Color.black : BPDesign.Colors.textPrimary)
              .frame(height: 36)
              .frame(maxWidth: .infinity)
              .background(currentAppearance == mode ? accent : elevated)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func apply(_ mode: AppearanceMode) {
    let defaults = UserDefaults.standard
    switch mode {
    case .system:
      defaults.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled)
      ThemeManager.shared.checkSystemMode()
    case .light:
      defaults.set(false, forKey: Constants.UserDefaults.systemThemeVariantEnabled)
      defaults.set(false, forKey: Constants.UserDefaults.themeDarkVariantEnabled)
      ThemeManager.shared.useDarkVariant = false
    case .dark:
      defaults.set(false, forKey: Constants.UserDefaults.systemThemeVariantEnabled)
      defaults.set(true, forKey: Constants.UserDefaults.themeDarkVariantEnabled)
      ThemeManager.shared.useDarkVariant = true
    }
    accountVersion += 1
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
          Text(displayName(from: accountService.account.email))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(BPDesign.Colors.textPrimary)

          Text(accountService.account.email)
            .font(.system(size: 13))
            .foregroundStyle(subtle)
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

  /// The account has no name field yet, so derive a friendly one from the email
  private func displayName(from email: String) -> String {
    let localPart = email.split(separator: "@").first.map(String.init) ?? email
    return localPart
      .replacingOccurrences(of: ".", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  private func menuRow(
    icon: String,
    title: Text,
    badge: Text? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: Spacing.S1) {
        Image(systemName: icon)
          .font(.system(size: 16))
          .foregroundStyle(accent)
          .frame(width: 28)

        title
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(BPDesign.Colors.textPrimary)

        Spacer()

        if let badge {
          badge
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(subtle)
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(subtle)
      }
      .padding(Spacing.S1)
      .background(elevated)
      .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var statsPage: some View {
    ZStack {
      background.ignoresSafeArea()

      ScrollView {
        let stats = session.listeningStats
        let tiles: [(LocalizedStringKey, Int)] = [
          ("profile_stats_day", stats.day),
          ("profile_stats_week", stats.week),
          ("profile_stats_month", stats.month),
          ("profile_stats_year", stats.year),
        ]

        VStack(alignment: .leading, spacing: Spacing.S2) {
          Text("profile_stats_title")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(BPDesign.Colors.textPrimary)

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
                  .foregroundStyle(BPDesign.Colors.textPrimary)
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
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
      }
    }
  }
}

/// Interests editing page: content-hugging chips, persisted on every toggle
struct CatalogInterestsPage: View {
  @State private var selectedGenres: Set<String>
  @State private var selectedLanguages: Set<String>

  private let background = BPDesign.Colors.inkBackground
  private let subtle = BPDesign.Colors.textSecondary
  private let accent = BPDesign.Colors.coral

  init() {
    let defaults = UserDefaults.standard
    _selectedGenres = State(initialValue: Set(
      defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedGenres) ?? []
    ))
    _selectedLanguages = State(initialValue: Set(
      defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedLanguages) ?? []
    ))
  }

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          Text("catalog_home_interests_title")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(BPDesign.Colors.textPrimary)

          section(
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

          section(
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
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
        .padding(.bottom, Spacing.L)
      }
    }
    .onAppear(perform: reload)
  }

  /// Always mirror what the onboarding (or a previous edit) persisted
  private func reload() {
    let defaults = UserDefaults.standard
    selectedGenres = Set(defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedGenres) ?? [])
    selectedLanguages = Set(defaults.stringArray(forKey: Constants.UserDefaults.onboardingSelectedLanguages) ?? [])
  }

  private func section<Content: View>(
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
      .foregroundStyle(isSelected ? Color.black : BPDesign.Colors.textPrimary)
      .padding(.horizontal, Spacing.S1)
      .frame(height: 34)
      .background(isSelected ? accent : Color.clear)
      .overlay(
        Capsule().stroke(isSelected ? Color.clear : BPDesign.Border.hairlineColor, lineWidth: 1)
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
    let defaults = UserDefaults.standard
    defaults.set(Array(selectedGenres).sorted(), forKey: Constants.UserDefaults.onboardingSelectedGenres)
    defaults.set(Array(selectedLanguages).sorted(), forKey: Constants.UserDefaults.onboardingSelectedLanguages)
  }
}

/// Subscription status and entry point to the real paywall
struct CatalogSubscriptionPage: View {
  @Environment(\.accountService) private var accountService

  let planName: LocalizedStringKey

  @State private var showPaywall = false

  private let background = BPDesign.Colors.inkBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondary
  private let accent = BPDesign.Colors.coral

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      VStack(spacing: Spacing.S1) {
        Spacer()

        ZStack {
          Circle().fill(accent.opacity(0.18))
          Image(systemName: "crown.fill")
            .font(.system(size: 34))
            .foregroundStyle(accent)
        }
        .frame(width: 92, height: 92)

        Text("profile_menu_subscription")
          .font(.system(size: 15))
          .foregroundStyle(subtle)

        Text(planName)
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(BPDesign.Colors.textPrimary)

        VStack(alignment: .leading, spacing: Spacing.S2) {
          benefitRow(Text("benefits_cloudsync_title"))
          benefitRow(Text(verbatim: "Apple Watch"))
          benefitRow(Text("benefits_themesicons_title"))
        }
        .padding(Spacing.S1)
        .background(elevated)
        .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
        .padding(.top, Spacing.S)

        Spacer()

        BPPrimaryButton(
          title: accountService.accessLevel == .free ? "profile_go_pro" : "profile_manage_subscription",
          isEnabled: true
        ) {
          showPaywall = true
        }
        .padding(.horizontal, Spacing.M)
        .padding(.bottom, Spacing.S)
      }
    }
    .sheet(isPresented: $showPaywall) {
      NavigationStack {
        CompleteAccountView {
          showPaywall = false
        }
      }
      .environmentObject(ThemeViewModel())
      .presentationDetents([.medium])
    }
  }

  private func benefitRow(_ title: Text) -> some View {
    HStack(spacing: Spacing.S2) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 15))
        .foregroundStyle(accent)

      title
        .font(.system(size: 14))
        .foregroundStyle(BPDesign.Colors.textPrimary)

      Spacer()
    }
  }
}

/// Full-screen mock player for catalog previews, opened from the mini-player.
/// Once real catalog audio exists this hands off to the app's PlayerManager.
struct CatalogPlayerView: View {
  @EnvironmentObject private var session: CatalogSession
  @Environment(\.dismiss) private var dismiss

  @State private var showChapters = false
  @State private var showAbout = false

  private let background = BPDesign.Colors.mediaBackground
  private let elevated = BPDesign.Colors.mediaSurfaceElevated
  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      if let book = session.nowPlaying {
        let chapters = session.chapters(for: book)
        let currentChapter = min(
          chapters.count,
          Int(session.progress(for: book) * Double(chapters.count)) + 1
        )

        ScrollView {
          VStack(spacing: Spacing.S1) {
          HStack {
            Button {
              dismiss()
            } label: {
              Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(subtle)
            }

            Spacer()

            Button {
              showChapters = true
            } label: {
              Image(systemName: "list.bullet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(subtle)
            }
          }
          .padding(.top, Spacing.S)

          RoundedRectangle(cornerRadius: 16)
            .fill(book.coverGradient)
            .frame(width: 280, height: 280)
            .padding(.top, Spacing.M)
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

            Button {
              showChapters = true
            } label: {
              HStack(spacing: Spacing.S3) {
                Text(String(
                  format: "player_chapter_position_format".localized,
                  currentChapter,
                  chapters.count
                ))
                Image(systemName: "chevron.up.chevron.down")
                  .font(.system(size: 10, weight: .semibold))
              }
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(accent)
            }
            .padding(.top, Spacing.S3)
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

          aboutSection(for: book)
            .padding(.top, Spacing.M)
          }
          .padding(.horizontal, Spacing.M)
          .padding(.bottom, Spacing.L)
        }
        .sheet(isPresented: $showChapters) {
          chaptersSheet(for: book, chapters: chapters, currentChapter: currentChapter)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAbout) {
          CatalogAboutSheet(book: book)
            .environmentObject(session)
        }
        .onAppear {
          #if DEBUG
          if ProcessInfo.processInfo.environment["BP_PREVIEW_ABOUT"] == "1" {
            showAbout = true
          }
          #endif
        }
      }
    }
  }

  /// Editorial about block: metadata chips, truncated synopsis with a
  /// "see more" modal, author row and a shelf of more titles by the author.
  /// In production the copy maps to Wikipedia/Amazon metadata.
  private func aboutSection(for book: CatalogBook) -> some View {
    VStack(alignment: .leading, spacing: Spacing.S) {
      CatalogMetadataChips(book: book)

      VStack(alignment: .leading, spacing: Spacing.S2) {
        CatalogSectionHeader(title: "player_about_book_title")

        Text(CatalogAboutContent.bookBlurb(book))
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.85))
          .lineSpacing(5)
          .lineLimit(3)
          .multilineTextAlignment(.leading)

        Button {
          showAbout = true
        } label: {
          HStack(spacing: Spacing.S3) {
            Text("player_about_see_more")
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
          }
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
      }

      Divider()
        .overlay(Color.white.opacity(0.08))

      Button {
        showAbout = true
      } label: {
        HStack(spacing: Spacing.S1) {
          CatalogAuthorAvatar(name: book.author, size: 44)

          VStack(alignment: .leading, spacing: 2) {
            Text(book.author)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)

            Text("player_about_author_caption")
              .font(.system(size: 12))
              .foregroundStyle(subtle)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(subtle)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      CatalogMoreByAuthorShelf(book: book)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func chaptersSheet(
    for book: CatalogBook,
    chapters: [CatalogSession.Chapter],
    currentChapter: Int
  ) -> some View {
    ZStack {
      background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S2) {
          Text("player_chapters_title")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .padding(.top, Spacing.M)

          ForEach(chapters) { chapter in
            Button {
              session.setProgress(chapter.startFraction, for: book)
              showChapters = false
            } label: {
              HStack {
                Text(String(format: "player_chapter_format".localized, chapter.id))
                  .font(.system(size: 15, weight: chapter.id == currentChapter ? .semibold : .regular))
                  .foregroundStyle(chapter.id == currentChapter ? accent : .white)

                if chapter.id == currentChapter {
                  Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
                }

                Spacer()

                Text(CatalogSession.formatMinutes(chapter.startMinutes))
                  .font(.system(size: 13))
                  .foregroundStyle(subtle)
              }
              .padding(Spacing.S1)
              .background(elevated)
              .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, Spacing.M)
        .padding(.bottom, Spacing.L)
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

/// Small uppercase section label used across the about surfaces
struct CatalogSectionHeader: View {
  let title: LocalizedStringKey

  var body: some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .kerning(0.8)
      .textCase(.uppercase)
      .foregroundStyle(BPDesign.Colors.textSecondaryMedia)
  }
}

/// Genre, duration and language pills
struct CatalogMetadataChips: View {
  let book: CatalogBook

  var body: some View {
    HStack(spacing: Spacing.S2) {
      if let genre = book.genre {
        chip(Text(genre.title))
      }
      chip(Text(verbatim: book.durationDescription))
      if let language = book.language {
        chip(Text(verbatim: language.nativeName))
      }
      Spacer()
    }
  }

  private func chip(_ text: Text) -> some View {
    text
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(BPDesign.Colors.textSecondaryMedia)
      .padding(.horizontal, Spacing.S1)
      .frame(height: 28)
      .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
  }
}

/// Initials avatar on a brand gradient
struct CatalogAuthorAvatar: View {
  let name: String
  var size: CGFloat = 44

  private var initials: String {
    name.split(separator: " ")
      .prefix(2)
      .compactMap { $0.first.map(String.init) }
      .joined()
      .uppercased()
  }

  var body: some View {
    ZStack {
      Circle().fill(
        LinearGradient(
          colors: [BPDesign.Colors.coral, BPDesign.Colors.bookBlue],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      Text(initials)
        .font(.system(size: size * 0.36, weight: .semibold))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}

/// Horizontal shelf with other titles by the same author
struct CatalogMoreByAuthorShelf: View {
  let book: CatalogBook

  private var authorBooks: [CatalogBook] {
    Array(
      CatalogMockLibrary.books
        .filter { $0.author == book.author && $0.id != book.id }
        .prefix(8)
    )
  }

  var body: some View {
    if !authorBooks.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.S2) {
        Text(String(format: "player_about_more_by_format".localized, book.author))
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: Spacing.S1) {
            ForEach(authorBooks) { authorBook in
              CatalogBookCard(book: authorBook, width: 110, forceDark: true)
            }
          }
        }
      }
    }
  }
}

/// Blurb copy; in production these strings come from Wikipedia/Amazon
enum CatalogAboutContent {
  static func bookBlurb(_ book: CatalogBook) -> String {
    String(
      format: "player_about_book_format".localized,
      book.title, book.author, book.genre?.title ?? ""
    )
  }

  static func fullBookText(_ book: CatalogBook) -> String {
    bookBlurb(book) + "\n\n" + String(
      format: "player_about_book_extra_format".localized,
      book.title, book.author, book.genre?.title ?? ""
    )
  }

  static func authorBlurb(_ book: CatalogBook) -> String {
    String(
      format: "player_about_author_format".localized,
      book.author, book.genre?.title ?? ""
    )
  }

  static func fullAuthorText(_ book: CatalogBook) -> String {
    authorBlurb(book) + "\n\n" + String(
      format: "player_about_author_extra_format".localized,
      book.author, book.genre?.title ?? ""
    )
  }
}

/// Expanded book/author information, opened from "see more"
struct CatalogAboutSheet: View {
  @EnvironmentObject private var session: CatalogSession

  let book: CatalogBook

  private let background = BPDesign.Colors.mediaBackground
  private let subtle = BPDesign.Colors.textSecondaryMedia

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          Text(book.title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)
            .padding(.top, Spacing.M)

          Text(book.author)
            .font(.system(size: 15))
            .foregroundStyle(subtle)

          CatalogMetadataChips(book: book)
            .padding(.top, Spacing.S3)

          CatalogSectionHeader(title: "player_about_book_title")
            .padding(.top, Spacing.S)

          Text(CatalogAboutContent.fullBookText(book))
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.88))
            .lineSpacing(6)

          CatalogSectionHeader(title: "player_about_author_title")
            .padding(.top, Spacing.S)

          HStack(spacing: Spacing.S1) {
            CatalogAuthorAvatar(name: book.author, size: 56)

            VStack(alignment: .leading, spacing: 2) {
              Text(book.author)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

              Text("player_about_author_caption")
                .font(.system(size: 12))
                .foregroundStyle(subtle)
            }

            Spacer()
          }

          Text(CatalogAboutContent.fullAuthorText(book))
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.88))
            .lineSpacing(6)

          CatalogMoreByAuthorShelf(book: book)
            .padding(.top, Spacing.S)

          Text("player_about_source")
            .font(.system(size: 11))
            .italic()
            .foregroundStyle(subtle)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.S)
        }
        .padding(.horizontal, Spacing.M)
        .padding(.bottom, Spacing.L)
      }
    }
  }
}

/// Design-system view over the user's real library, with a return.
/// Empty state offers the single import action; the full legacy library
/// remains reachable from the footer.
struct CatalogLibraryView: View {
  let onImportFiles: ([URL]) -> Void
  let onOpenFull: () -> Void

  @State private var items: [SimpleLibraryItem] = []
  @State private var showPicker = false

  private let background = BPDesign.Colors.inkBackground
  private let elevated = BPDesign.Colors.surfaceElevated
  private let subtle = BPDesign.Colors.textSecondary
  private let accent = BPDesign.Colors.coral

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      if items.isEmpty {
        VStack(spacing: Spacing.S1) {
          Spacer()

          ZStack {
            Circle().fill(accent.opacity(0.18))
            Image(systemName: "books.vertical.fill")
              .font(.system(size: 34))
              .foregroundStyle(accent)
          }
          .frame(width: 92, height: 92)
          .padding(.bottom, Spacing.S)

          Text("catalog_library_title")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(BPDesign.Colors.textPrimary)

          Text("uploads_empty_description")
            .font(.system(size: 15))
            .foregroundStyle(subtle)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.L)

          Spacer()

          BPPrimaryButton(title: "uploads_choose_files", isEnabled: true) {
            showPicker = true
          }
          .padding(.horizontal, Spacing.M)
          .padding(.bottom, Spacing.S)
        }
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: Spacing.S1) {
            Text("catalog_library_title")
              .font(.system(size: 24, weight: .bold))
              .foregroundStyle(BPDesign.Colors.textPrimary)

            Text(String(
              format: "catalog_home_books_format".localized,
              CatalogMockLibrary.formattedCount(items.count)
            ))
            .font(.system(size: 13))
            .foregroundStyle(subtle)

            ForEach(items) { item in
              libraryRow(item)
            }

            Button(action: onOpenFull) {
              Text("catalog_library_open_full")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BPDesign.Colors.textPrimary)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(elevated)
                .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.button))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.S)
          }
          .padding(.horizontal, Spacing.M)
          .padding(.top, Spacing.S)
          .padding(.bottom, Spacing.L)
        }
      }
    }
    .toolbarBackground(background, for: .navigationBar)
    .onAppear {
      items = AppServices.shared.coreServices?.libraryService
        .fetchContents(at: nil, limit: nil, offset: nil) ?? []
    }
    .sheet(isPresented: $showPicker) {
      AudioDocumentPicker { urls in
        showPicker = false
        onImportFiles(urls)
      }
      .ignoresSafeArea()
    }
  }

  private func libraryRow(_ item: SimpleLibraryItem) -> some View {
    HStack(spacing: Spacing.S1) {
      ZStack {
        RoundedRectangle(cornerRadius: 6)
          .fill(
            LinearGradient(
              colors: [BPDesign.Colors.bookBlue, BPDesign.Colors.coralSoft],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: item.type == .folder ? "folder.fill" : "headphones")
          .font(.system(size: 18))
          .foregroundStyle(.white)
      }
      .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(BPDesign.Colors.textPrimary)
          .lineLimit(1)

        Text(item.durationFormatted)
          .font(.system(size: 12))
          .foregroundStyle(subtle)
      }

      Spacer()

      if item.progress > 0, !item.isFinished {
        Text(verbatim: "\(Int(item.progress * 100))%")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accent)
      } else if item.isFinished {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(accent)
      }
    }
    .padding(Spacing.S2)
    .background(elevated)
    .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.card))
  }
}
