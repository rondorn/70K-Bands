//
//  PortraitFilterSheetView.swift
//  70K Bands
//
//  Portrait filter menu sheet - uses shared CommonFilterSheetView
//

import SwiftUI

struct PortraitFilterSheetView: View {
    @State private var dayBeforeFilterChange: String? = nil
    var onDismiss: (() -> Void)?
    
    var body: some View {
        CommonFilterSheetView(
            menuOrder: .portrait,
            dayData: nil,
            viewModel: nil,
            dayBeforeFilterChange: $dayBeforeFilterChange,
            onDismiss: onDismiss
        )
    }
}
