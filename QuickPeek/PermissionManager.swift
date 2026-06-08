//
//  PermissionManager.swift
//  QuickPeek
//
//  Created by Assistant on 1/21/26.
//

import Foundation

/// Manages security-scoped bookmarks and provides simple single-task/ZIP lifecycle coordination.
final class PermissionManager {
    static let shared = PermissionManager()
    
    private let defaults = UserDefaults.standard
    private let bookmarkKeyPrefix = "bookmark_"
    
    // MARK: - Single active task/ZIP tracking
    private let stateQueue = DispatchQueue(label: "PermissionManager.stateQueue")
    private var currentTask: Task<Void, Never>? = nil
    private var currentZipURL: URL? = nil
    
    private init() {}
    
    // MARK: - Single process/task management
    /// Registers a new processing task. If there is an existing task, it will be cancelled first.
    /// - Parameter makeTask: Closure that creates and returns the new Task to run. The closure will be invoked on the caller's context.
    func startSingleTask(makeTask: () -> Task<Void, Never>) {
        stateQueue.sync {
            // Cancel any existing task before starting a new one
            currentTask?.cancel()
            currentTask = makeTask()
        }
    }

    /// Cancels the current task if any and clears the reference.
    func cancelCurrentTask() {
        stateQueue.sync {
            currentTask?.cancel()
            currentTask = nil
        }
    }

    // MARK: - ZIP lifecycle management
    /// Call this before starting to read a new ZIP. It clears any state from the previous ZIP and records the new URL.
    /// - Parameter url: The URL of the ZIP that is about to be processed.
    func beginReadingZip(at url: URL) {
        stateQueue.sync {
            // If switching to a different ZIP, clear previous info first
            if let previous = currentZipURL, previous != url {
                clearZipStateLocked(previous)
            }
            currentZipURL = url
        }
    }

    /// Call this when finished with the current ZIP to release memory/state.
    func endReadingCurrentZip() {
        stateQueue.sync {
            if let current = currentZipURL {
                clearZipStateLocked(current)
            }
            currentZipURL = nil
        }
    }

    /// Clears any retained state/resources associated with the given ZIP.
    /// Note: Adjust this implementation to clear your app's actual caches, extracted file handles, temp directories, etc.
    private func clearZipStateLocked(_ url: URL) {
        // If you maintain temp extraction directories per ZIP, remove them here.
        // If you cache entries/metadata in-memory, drop those references here.
        // This placeholder intentionally does nothing besides logging.
        #if DEBUG
        print("Clearing state for ZIP: \(url.path)")
        #endif
    }
    
    func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: bookmarkKeyPrefix + url.path)
            print("Bookmark saved for: \(url.path)")
        } catch {
            print("Failed to save bookmark for \(url.path): \(error)")
        }
    }
    
    func resolveBookmark(for path: String) -> URL? {
        guard let data = defaults.data(forKey: bookmarkKeyPrefix + path) else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Bookmark is stale, renewing...")
                saveBookmark(for: url)
            }
            
            if url.startAccessingSecurityScopedResource() {
                return url
            } else {
                print("Failed to access security scoped resource for \(path)")
                return nil
            }
        } catch {
            print("Failed to resolve bookmark for \(path): \(error)")
            return nil
        }
    }
    
    func clearBookmark(for path: String) {
        defaults.removeObject(forKey: bookmarkKeyPrefix + path)
    }
    
    // MARK: - Utilities
    /// Removes all stored security-scoped bookmarks managed by this instance.
    func clearAllBookmarks() {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(bookmarkKeyPrefix) }
        for key in keys { defaults.removeObject(forKey: key) }
    }
    
    /// Deletes all temporary ZIP extraction folders created during the app session.
    /// Call this at program exit to ensure no temp files are left behind.
    static func cleanupAllZipTempDirectories() {
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(atPath: tempDir) {
            for case let directory as String in enumerator {
                if directory.hasPrefix("QuickPeek_") {
                    let fullPath = (tempDir as NSString).appendingPathComponent(directory)
                    do {
                        try fileManager.removeItem(atPath: fullPath)
                        #if DEBUG
                        print("[PermissionManager] Deleted temp extraction folder: \(fullPath)")
                        #endif
                    } catch {
                        print("[PermissionManager] Failed to delete temp folder \(fullPath): \(error)")
                    }
                }
            }
        }
    }
}
