//
//  AboutView.swift
//  70K Bands
//
//  Created by Assistant on 2/5/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    private let aboutTeam = FestivalConfig.current.aboutTeam

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(DataIntegrityTag.suiteDisplayLabel())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                // About heading
                Text(NSLocalizedString("About", comment: "About screen title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Main description (English only; festival/app names from festival.json)
                Group {
                    Text(processAboutDescription("AboutDescription1"))
                    Text(processAboutDescription("AboutDescription2"))
                    Text(processAboutDescription("AboutDescription3"))
                    Text(processAboutDescription("AboutDescription4"))
                    Text(processAboutDescription("AboutDescription5"))
                }
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                
                // Copyright
                Text(NSLocalizedString("AboutCopyright", comment: "Copyright notice"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                Divider()
                    .padding(.vertical, 10)
                
                // Team section
                Text(NSLocalizedString("AboutTheTeam", comment: "The Team section heading"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 5)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(aboutTeam.members.indices, id: \.self) { index in
                        teamMember(aboutTeam.members[index])
                    }
                }
                .padding(.bottom, 20)
                
                Spacer(minLength: 30)
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("About", comment: "About screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    private func teamMember(_ member: AboutTeamMember) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(member.name)
                .font(.body)
                .fontWeight(.medium)
            Text(formattedRole(for: member))
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(member.photoAssetNames.indices, id: \.self) { photoIndex in
                if let image = loadAboutPhoto(named: member.photoAssetNames[photoIndex]) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.top, photoIndex == 0 ? 8 : 4)
                }
            }
        }
    }

    /// Loads a bundled About-team image by resource name (with or without file extension).
    private func loadAboutPhoto(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        let baseName = (name as NSString).deletingPathExtension
        if baseName != name, let image = UIImage(named: baseName) {
            return image
        }
        for ext in ["png", "jpg", "jpeg"] {
            if let url = Bundle.main.url(forResource: baseName, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    private func formattedRole(for member: AboutTeamMember) -> String {
        let role = NSLocalizedString(member.roleTranslationKey, comment: "About team member role")
        if let positionKey = member.photoPositionTranslationKey {
            let position = NSLocalizedString(positionKey, comment: "About team photo position")
            return "\(role) (\(position))"
        }
        return role
    }
    
    /// Replaces !FESTIVAL_NAME! and !APP_NAME! from festival.json (English-only About copy).
    private func processAboutDescription(_ key: String) -> String {
        let template = NSLocalizedString(key, comment: "About description paragraph")
        let config = FestivalConfig.current
        return template
            .replacingOccurrences(of: "!FESTIVAL_NAME!", with: config.festivalName)
            .replacingOccurrences(of: "!APP_NAME!", with: config.appName)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
