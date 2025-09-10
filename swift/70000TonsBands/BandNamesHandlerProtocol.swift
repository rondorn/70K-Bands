//
//  BandNamesHandlerProtocol.swift
//  70000TonsBands
//
//  Protocol for bandNamesHandler interface
//

import Foundation

/// Protocol that defines the essential bandNamesHandler interface
protocol BandNamesHandlerProtocol {
    func getBandNames() -> [String]
    func getBandImageUrl(_ band: String) -> String
    func getofficalPage(_ band: String) -> String
    func getWikipediaPage(_ bandName: String) -> String
    func getYouTubePage(_ bandName: String) -> String
    func getMetalArchives(_ bandName: String) -> String
    func getBandCountry(_ band: String) -> String
    func getBandGenre(_ band: String) -> String
    func getBandNoteWorthy(_ band: String) -> String
    func getPriorYears(_ band: String) -> String
    func getCachedData(forceNetwork: Bool, completion: (() -> Void)?)
    func gatherData(forceDownload: Bool, isYearChangeOperation: Bool, completion: (() -> Void)?)
    func gatherData(forceDownload: Bool, completion: (() -> Void)?)
    func readBandFile()
    func populateCache(completion: (() -> Void)?)
    func clearCachedData()
    func writeBandFile(_ httpData: String)
    func forceReadBandFileAndPopulateCache(completion: (() -> Void)?)
}

/// Extension to make bandNamesHandler conform to protocol
extension bandNamesHandler: BandNamesHandlerProtocol {
    // Already implements all required methods
}


