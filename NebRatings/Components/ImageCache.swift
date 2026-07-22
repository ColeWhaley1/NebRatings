//
//  ImageCache.swift
//  NebRatings
//
//  Shared image loading + caching for every poster, backdrop, headshot and
//  logo in the app. SwiftUI's AsyncImage re-downloads on every reappear and
//  can't be prefetched, which is why posters "popped in" as rows scrolled.
//
//  This gives us:
//    • an in-memory decoded-image cache (instant redisplay, no flicker),
//    • a disk-backed URLCache underneath (survives across launches),
//    • a `prefetch` API so we can warm images BEFORE they scroll on screen.
//

import UIKit

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession
    /// De-dupes concurrent requests for the same URL (e.g. a visible cell and
    /// a prefetch both asking at once).
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 48 * 1024 * 1024,     // 48 MB
            diskCapacity: 320 * 1024 * 1024        // 320 MB
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        memory.countLimit = 500
    }

    /// Synchronous hit — lets a view paint instantly with zero flicker when
    /// the image is already decoded in memory.
    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    /// Loads (or returns cached) decoded image for a URL.
    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }

        lock.lock()
        if let existing = inFlight[url] {
            lock.unlock()
            return await existing.value
        }
        let task = Task<UIImage?, Never> { [session, memory] in
            guard let (data, _) = try? await session.data(from: url),
                  let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL)
            return image
        }
        inFlight[url] = task
        lock.unlock()

        let result = await task.value
        lock.lock(); inFlight[url] = nil; lock.unlock()
        return result
    }

    /// Warms the cache for URLs that aren't on screen yet. Low priority so it
    /// never competes with images the user is actually looking at.
    func prefetch(_ urlStrings: [String?]) {
        for case let s? in urlStrings {
            guard let url = URL(string: s), !s.isEmpty,
                  memory.object(forKey: url as NSURL) == nil else { continue }
            Task.detached(priority: .utility) { [weak self] in
                _ = await self?.image(for: url)
            }
        }
    }
}
