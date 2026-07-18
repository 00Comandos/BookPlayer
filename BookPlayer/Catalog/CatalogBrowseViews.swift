//
//  CatalogBrowseViews.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

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

/// Avatar sheet: profile info when signed in, login entry point otherwise
struct CatalogProfileSheet: View {
  @Environment(\.accountService) private var accountService
  @Environment(\.dismiss) private var dismiss

  let onGoLibrary: () -> Void

  @State private var showLogin = false

  private let background = BPDesign.Colors.mediaBackground
  private let subtle = BPDesign.Colors.textSecondaryMedia
  private let accent = BPDesign.Colors.coral

  var body: some View {
    VStack(spacing: Spacing.S1) {
      ZStack {
        Circle().fill(accent.opacity(0.25))
        Image(systemName: "person.fill")
          .font(.system(size: 34))
          .foregroundStyle(accent)
      }
      .frame(width: 84, height: 84)
      .padding(.top, Spacing.L)

      if accountService.hasAccount() {
        Text(accountService.account.email)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
      } else {
        Text("catalog_home_profile_guest")
          .font(.system(size: 15))
          .foregroundStyle(subtle)

        BPPrimaryButton(title: "catalog_home_profile_login", isEnabled: true) {
          showLogin = true
        }
        .padding(.horizontal, Spacing.M)
        .padding(.top, Spacing.S)
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
          .background(BPDesign.Colors.mediaSurfaceElevated)
          .clipShape(RoundedRectangle(cornerRadius: BPDesign.Radius.button))
      }
      .padding(.horizontal, Spacing.M)
      .padding(.top, Spacing.S)

      Spacer()
    }
    .frame(maxWidth: .infinity)
    .background(background.ignoresSafeArea())
    .sheet(isPresented: $showLogin) {
      NavigationStack {
        LoginView()
      }
      .environmentObject(ThemeViewModel())
    }
  }
}
