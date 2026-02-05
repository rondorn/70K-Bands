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
                Text("About")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Main description
                Group {
                    Text("This is an unofficial, open-source application designed to help users discover bands and artists appearing at multiple music festivals, and to view event schedules, times, and venues in one place.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("The app allows users to browse artists, explore event listings, and stay organized while attending festivals. It is designed to work across different events without being tied to any single festival, promoter, or organizer.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("This application is not affiliated with, endorsed by, or officially connected to any festival, event organizer, promoter, or performing artist. All artist names, event names, and related information remain the property of their respective owners and are used for informational purposes only.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("The source code for this application is open-sourced and licensed under the GNU General Public License, version 2 (GPL-2.0).")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
                .foregroundColor(.primary)
                
                // Copyright
                Text("Copyright © 2015–present")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                Divider()
                    .padding(.vertical, 10)
                
                // Team section
                Text("The Team")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 5)
                
                VStack(alignment: .leading, spacing: 8) {
                    teamMember(name: "Ron Dorn", role: "Lead developer and creator", position: "center")
                    teamMember(name: "Robert Jan de Vries", role: "UI Designer", position: "right")
                    teamMember(name: "Aaron Copeland", role: "70K Bands Summary Curator", position: "left")
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
                            Text("Team Photo")
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(10)
                }
                
                Spacer(minLength: 30)
            }
            .padding()
        }
        .navigationTitle("About")
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
}

#Preview {
    NavigationView {
        AboutView()
    }
}
