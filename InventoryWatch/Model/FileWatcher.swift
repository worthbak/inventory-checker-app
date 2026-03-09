//
//  FileWatcher.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let directoryURL: URL
    private let callback: () -> Void

    init(directoryURL: URL, callback: @escaping () -> Void) {
        self.directoryURL = directoryURL
        self.callback = callback
    }

    func startWatching() {
        stopWatching()

        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.callback()
        }

        source.setCancelHandler {
            close(fd)
        }

        self.source = source
        source.resume()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }

    deinit {
        stopWatching()
    }
}
