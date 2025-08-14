//
//  SwiftUIToast.swift
//  70K Bands
//
//  Created by Assistant on 1/14/25.
//  Copyright (c) 2025 Ron Dorn. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Toast Implementation

struct ToastView: View {
    let message: String
    let placeHigh: Bool
    
    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .shadow(radius: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let placeHigh: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    if !placeHigh {
                        Spacer()
                    }
                    
                    ToastView(message: message, placeHigh: placeHigh)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1000)
                    
                    if placeHigh {
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, placeHigh ? 100 : 150)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: isShowing) { showing in
            if showing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, placeHigh: Bool = false) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, placeHigh: placeHigh))
    }
}

// ToastManager is now defined in DetailViewModel.swift
