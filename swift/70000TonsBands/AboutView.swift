//
//  AboutView.swift
//  70K Bands
//
//  Created by Assistant on 2/5/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // About heading
                Text(NSLocalizedString("About", comment: "About screen title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Main description
                Group {
                    Text(processAboutDescription1())
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(NSLocalizedString("AboutDescription3", comment: "Third paragraph of About description - disclaimer"))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(NSLocalizedString("AboutDescription4", comment: "Fourth paragraph of About description - GPL license"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
                .foregroundColor(.primary)
                
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
                    teamMember(name: "Ron Dorn", role: NSLocalizedString("AboutRoleLeadDeveloper", comment: "Lead developer role"), position: NSLocalizedString("AboutPositionCenter", comment: "Center position"))
                    teamMember(name: "Robert Jan de Vries", role: NSLocalizedString("AboutRoleUIDesigner", comment: "UI Designer role"), position: NSLocalizedString("AboutPositionRight", comment: "Right position"))
                    teamMember(name: "Aaron Copeland", role: NSLocalizedString("AboutRoleCurator", comment: "Curator role"), position: NSLocalizedString("AboutPositionLeft", comment: "Left position"))
                }
                .padding(.bottom, 20)
                
                // Team photo
                if let image = UIImage(named: "about-team.png") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                } else {
                    // Fallback if image is not found
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text(NSLocalizedString("AboutTeamPhoto", comment: "Team photo placeholder"))
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(10)
                }
                
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
    
    private func teamMember(name: String, role: String, position: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.body)
                .fontWeight(.medium)
            Text("\(role) (\(position))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// Processes the first About description paragraph, replacing !FESTIVALE_NAME! with the actual festival name
    private func processAboutDescription1() -> String {
        let template = NSLocalizedString("AboutDescription1", comment: "First paragraph of About description")
        let festivalName = FestivalConfig.current.festivalName
        return template.replacingOccurrences(of: "!FESTIVALE_NAME!", with: festivalName)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
