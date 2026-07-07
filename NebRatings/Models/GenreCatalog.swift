//
//  GenreCatalog.swift
//  NebRatings
//
//  Static genre vocabulary used for hand-picked favorite genres and (later)
//  genre-driven Discover sections. Names match TMDB's genre names so they
//  interoperate with `UserProfile.genreCounts` and TMDB Discover filters.
//

import Foundation

enum GenreCatalog {
    /// Genres a user can pick as favorites — the TMDB movie list plus the
    /// TV-only names users actually recognize, deduped and alphabetized.
    static let selectableGenres: [String] = [
        "Action",
        "Adventure",
        "Animation",
        "Comedy",
        "Crime",
        "Documentary",
        "Drama",
        "Family",
        "Fantasy",
        "History",
        "Horror",
        "Music",
        "Mystery",
        "Reality",
        "Romance",
        "Science Fiction",
        "Thriller",
        "War",
        "Western"
    ]

    /// Max hand-picked favorite genres per profile.
    static let maxFavorites = 5

    /// TMDB numeric genre IDs by name, for Discover queries. Movie IDs are
    /// used where movie/TV IDs differ but the concept matches; names missing
    /// here can't drive a Discover filter.
    static let tmdbGenreIDs: [String: Int] = [
        "Action": 28,
        "Adventure": 12,
        "Animation": 16,
        "Comedy": 35,
        "Crime": 80,
        "Documentary": 99,
        "Drama": 18,
        "Family": 10751,
        "Fantasy": 14,
        "History": 36,
        "Horror": 27,
        "Music": 10402,
        "Mystery": 9648,
        "Reality": 10764,
        "Romance": 10749,
        "Science Fiction": 878,
        "Thriller": 53,
        "War": 10752,
        "Western": 37
    ]

    /// TV-side genre IDs for names whose TV id differs from the movie id.
    static let tmdbTVGenreIDs: [String: Int] = [
        "Action": 10759,          // Action & Adventure
        "Adventure": 10759,       // Action & Adventure
        "Science Fiction": 10765, // Sci-Fi & Fantasy
        "Fantasy": 10765,         // Sci-Fi & Fantasy
        "War": 10768              // War & Politics
    ]
}
