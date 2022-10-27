//
//  GithubModel.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

actor GithubModel {
    
    enum Error: Swift.Error {
        case failedToInitURL
        case failedToParseGithubVersion
    }
    
    let localAppVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    var latestFetchedReleaseVersion: String?
    
    func hasLatestGithubRelease() async throws -> Bool {
        guard let url = URL(string: "https://api.github.com/repos/worthbak/inventory-checker-app/tags") else {
            throw Error.failedToInitURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let parsed = try JSONDecoder().decode([GithubTag].self, from: data)
        
        let processedData = parsed
            .filter { !$0.name.hasPrefix("v") }
            .sorted { first, second in
                switch compareNumeric(first.name, second.name) {
                case .orderedAscending, .orderedSame:
                    return false
                case .orderedDescending:
                    return true
                }
            }
        
        guard let latestReleaseVersion = processedData.first?.name else {
            throw Error.failedToParseGithubVersion
        }
        
        latestFetchedReleaseVersion = latestReleaseVersion
        
        let isLatestRelease: Bool
        switch compareNumeric(latestReleaseVersion, localAppVersion) {
        case .orderedAscending, .orderedSame:
            isLatestRelease = true
        case .orderedDescending:
            isLatestRelease = false
        }
        
        return isLatestRelease
    }
    
}
