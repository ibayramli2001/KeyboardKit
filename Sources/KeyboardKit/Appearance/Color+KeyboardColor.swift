//
//  Color+KeyboardColor.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-20.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Color {
    
    static var standardButton: Color = color(for: .standardButton)
    static var standardButtonTint: Color = color(for: .standardButtonTint)
    static var standardDarkButton: Color = color(for: .standardDarkButton)
    static var standardDarkButtonTint: Color = color(for: .standardButtonTint)
    
    static var standardButtonShadow: Color = color(for: .standardButtonShadow)
    
    static var standardDarkAppearanceButton: Color = color(for: .standardDarkAppearanceButton)
    static var standardDarkAppearanceButtonTint: Color = color(for: .standardDarkAppearanceButtonTint)
    static var standardDarkAppearanceDarkButton: Color = color(for: .standardDarkAppearanceDarkButton)
    static var standardDarkAppearanceDarkButtonTint: Color = color(for: .standardDarkAppearanceButtonTint)
}

private extension Color {
    
    static func color(for color: KeyboardColor) -> Color {
        color.color
    }
}

struct ColorResources_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(KeyboardColor.allCases) { color in
                HStack {
                    color.color
                    color.color.colorScheme(.dark)
                }.frame(height: 100)
            }
        }.previewLayout(.sizeThatFits)
    }
}
