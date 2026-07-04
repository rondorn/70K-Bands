//
//  FestivalConfigLoader.swift
//  Loads config/festivals/*.json (bundled as festival.json at build time).
//

import Foundation

private struct PlatformAsset: Codable {
    let android: String?
    let ios: String?

    func resolved(platform: String) -> String {
        switch platform {
        case "ios":
            return ios ?? android ?? ""
        default:
            return android ?? ios ?? ""
        }
    }
}

private struct FestivalVenueJson: Codable {
    let name: String
    let color: String
    let location: String
    let goingIcon: PlatformAsset
    let notGoingIcon: PlatformAsset
}

private struct GenericVenueSlotJson: Codable {
    let color: String
    let goingIcon: PlatformAsset
    let notGoingIcon: PlatformAsset
}

private struct AboutTeamMemberJson: Codable {
    let name: String
    let roleTranslationKey: String
    let photoPositionTranslationKey: String?
    let photo: PlatformAsset?
    let photos: [PlatformAsset]?

    func resolvedPhotoAssets(platform: String) -> [String] {
        let assets: [PlatformAsset]
        if let photos = photos, !photos.isEmpty {
            assets = photos
        } else if let photo = photo {
            assets = [photo]
        } else {
            return []
        }
        return assets.map { $0.resolved(platform: platform) }.filter { !$0.isEmpty }
    }
}

private struct AboutTeamJson: Codable {
    let members: [AboutTeamMemberJson]
}

struct AboutTeamMember {
    let name: String
    let roleTranslationKey: String
    let photoPositionTranslationKey: String?
    let photoAssetNames: [String]
}

struct AboutTeamConfig {
    let members: [AboutTeamMember]
}

private struct FestivalConfigJson: Codable {
    let festivalShortName: String
    let festivalName: String
    let appName: String
    let packageName: String
    let bundleIdentifier: String
    let defaultStorageUrl: String
    let defaultStorageUrlTest: String
    let firebaseConfigFile: PlatformAsset
    let subscriptionTopic: String?
    let subscriptionTopicTest: String?
    let subscriptionUnofficalTopic: String?
    let artistUrlDefault: String
    let scheduleUrlDefault: String
    let logo: PlatformAsset
    let shareUrl: String
    let shareFileExtension: String
    let notificationChannelId: String
    let notificationChannelName: String
    let notificationChannelDescription: String
    let graphics: GraphicsJson
    let venues: [FestivalVenueJson]
    let genericVenueSlots: [GenericVenueSlotJson]
    let meetAndGreetsEnabledDefault: Bool
    let specialEventsEnabledDefault: Bool
    let unofficalEventsEnabledDefault: Bool
    let eventTypeDisplayNames: [String: [String: String]]
    let eventTypeFilterDisplayNames: [String: [String: String]]
    let commentsNotAvailableTranslationKey: String
    let aiSchedule: Bool
    let scheduleQRShareEnabled: Bool
    /// Custom URL for guide QR (camera app opens in-app schedule scanner). Omitted when not configured.
    let scheduleQRGuideURL: String?
    let about: AboutTeamJson

    struct GraphicsJson: Codable {
        let mustSeeIconSmall: PlatformAsset
        let mightSeeIconSmall: PlatformAsset
        let wontSeeIconSmall: PlatformAsset
        let unknownIconSmall: PlatformAsset
        let mustSeeIcon: PlatformAsset
        let mustSeeIconAlt: PlatformAsset
        let mightSeeIcon: PlatformAsset
        let mightSeeIconAlt: PlatformAsset
        let wontSeeIcon: PlatformAsset
        let wontSeeIconAlt: PlatformAsset
        let unknownIcon: PlatformAsset
        let unknownIconAlt: PlatformAsset
        let preferencesIcon: PlatformAsset
        let shareIcon: PlatformAsset
        let statsIcon: PlatformAsset
        let fallbackMiscGenericGoingIcon: PlatformAsset
        let fallbackMiscGenericNotGoingIcon: PlatformAsset
    }
}

private struct FestivalRegistryJson: Codable {
    let shareFileExtensions: [String]
    let subscriptionTopic: String
    let subscriptionTopicTest: String
    let subscriptionUnofficalTopic: String
}

/// Parsed festival.json with iOS asset names resolved.
struct FestivalConfigPayload {
    let festivalShortName: String
    let festivalName: String
    let appName: String
    let bundleIdentifier: String
    let defaultStorageUrl: String
    let defaultStorageUrlTest: String
    let firebaseConfigFile: String
    let subscriptionTopic: String
    let subscriptionTopicTest: String
    let subscriptionUnofficalTopic: String
    let artistUrlDefault: String
    let scheduleUrlDefault: String
    let logoUrl: String
    let shareUrl: String
    let shareFileExtension: String
    let mustSeeIconSmall: String
    let mightSeeIconSmall: String
    let wontSeeIconSmall: String
    let unknownIconSmall: String
    let mustSeeIcon: String
    let mustSeeIconAlt: String
    let mightSeeIcon: String
    let mightSeeIconAlt: String
    let wontSeeIcon: String
    let wontSeeIconAlt: String
    let unknownIcon: String
    let unknownIconAlt: String
    let preferencesIcon: String
    let shareIcon: String
    let statsIcon: String
    let venues: [Venue]
    let genericVenueSlots: [GenericVenueSlot]
    let meetAndGreetsEnabledDefault: Bool
    let specialEventsEnabledDefault: Bool
    let unofficalEventsEnabledDefault: Bool
    let eventTypeDisplayNames: [String: [String: String]]
    let eventTypeFilterDisplayNames: [String: [String: String]]
    let commentsNotAvailableTranslationKey: String
    let aiSchedule: Bool
    let scheduleQRShareEnabled: Bool
    let scheduleQRGuideURL: String
    let peerShareFileExtensions: [String]
    let fallbackMiscGenericGoingIcon: String
    let fallbackMiscGenericNotGoingIcon: String
    let aboutTeam: AboutTeamConfig
}

enum FestivalConfigLoader {

    private static let platform = "ios"

    static func loadFromBundle() -> FestivalConfigPayload {
        guard let festivalUrl = Bundle.main.url(forResource: "festival", withExtension: "json") else {
            fatalError("festival.json missing from app bundle — ensure copy-festival-config.sh runs before compile")
        }
        let festivalData = try! Data(contentsOf: festivalUrl)
        let json = try! JSONDecoder().decode(FestivalConfigJson.self, from: festivalData)

        guard let registryUrl = Bundle.main.url(forResource: "festival_registry", withExtension: "json"),
              let registryData = try? Data(contentsOf: registryUrl),
              let registry = try? JSONDecoder().decode(FestivalRegistryJson.self, from: registryData) else {
            fatalError("festival_registry.json missing from app bundle")
        }

        let shareExtensions = registry.shareFileExtensions

        let g = json.graphics
        func r(_ a: PlatformAsset) -> String { a.resolved(platform: platform) }

        return FestivalConfigPayload(
            festivalShortName: json.festivalShortName,
            festivalName: json.festivalName,
            appName: json.appName,
            bundleIdentifier: json.bundleIdentifier,
            defaultStorageUrl: json.defaultStorageUrl,
            defaultStorageUrlTest: json.defaultStorageUrlTest,
            firebaseConfigFile: r(json.firebaseConfigFile),
            subscriptionTopic: json.subscriptionTopic ?? registry.subscriptionTopic,
            subscriptionTopicTest: json.subscriptionTopicTest ?? registry.subscriptionTopicTest,
            subscriptionUnofficalTopic: json.subscriptionUnofficalTopic ?? registry.subscriptionUnofficalTopic,
            artistUrlDefault: json.artistUrlDefault,
            scheduleUrlDefault: json.scheduleUrlDefault,
            logoUrl: r(json.logo),
            shareUrl: json.shareUrl,
            shareFileExtension: json.shareFileExtension,
            mustSeeIconSmall: r(g.mustSeeIconSmall),
            mightSeeIconSmall: r(g.mightSeeIconSmall),
            wontSeeIconSmall: r(g.wontSeeIconSmall),
            unknownIconSmall: r(g.unknownIconSmall),
            mustSeeIcon: r(g.mustSeeIcon),
            mustSeeIconAlt: r(g.mustSeeIconAlt),
            mightSeeIcon: r(g.mightSeeIcon),
            mightSeeIconAlt: r(g.mightSeeIconAlt),
            wontSeeIcon: r(g.wontSeeIcon),
            wontSeeIconAlt: r(g.wontSeeIconAlt),
            unknownIcon: r(g.unknownIcon),
            unknownIconAlt: r(g.unknownIconAlt),
            preferencesIcon: r(g.preferencesIcon),
            shareIcon: r(g.shareIcon),
            statsIcon: r(g.statsIcon),
            venues: json.venues.map {
                Venue(
                    name: $0.name,
                    color: $0.color,
                    goingIcon: r($0.goingIcon),
                    notGoingIcon: r($0.notGoingIcon),
                    location: $0.location
                )
            },
            genericVenueSlots: json.genericVenueSlots.map {
                GenericVenueSlot(
                    color: $0.color,
                    goingIcon: r($0.goingIcon),
                    notGoingIcon: r($0.notGoingIcon)
                )
            },
            meetAndGreetsEnabledDefault: json.meetAndGreetsEnabledDefault,
            specialEventsEnabledDefault: json.specialEventsEnabledDefault,
            unofficalEventsEnabledDefault: json.unofficalEventsEnabledDefault,
            eventTypeDisplayNames: json.eventTypeDisplayNames,
            eventTypeFilterDisplayNames: json.eventTypeFilterDisplayNames,
            commentsNotAvailableTranslationKey: json.commentsNotAvailableTranslationKey,
            aiSchedule: json.aiSchedule,
            scheduleQRShareEnabled: json.scheduleQRShareEnabled,
            scheduleQRGuideURL: json.scheduleQRGuideURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            peerShareFileExtensions: shareExtensions,
            fallbackMiscGenericGoingIcon: r(g.fallbackMiscGenericGoingIcon),
            fallbackMiscGenericNotGoingIcon: r(g.fallbackMiscGenericNotGoingIcon),
            aboutTeam: AboutTeamConfig(
                members: json.about.members.map {
                    AboutTeamMember(
                        name: $0.name,
                        roleTranslationKey: $0.roleTranslationKey,
                        photoPositionTranslationKey: $0.photoPositionTranslationKey,
                        photoAssetNames: $0.resolvedPhotoAssets(platform: platform)
                    )
                }
            )
        )
    }
}
