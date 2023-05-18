//
//  VisionLabel.swift
//  AccessbilitySampleApp
//
//  Created by Ashish Awasthi on 18/05/23.
//

import SwiftUI

struct VisionLabel: View {
    @State var title: String
    @State var image: String = ""
    @State var alignment: Alignment = .leading

    var body: some View {
        Label(title, systemImage: image)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

struct VisionLabel_Previews: PreviewProvider {

    static var previews: some View {
        VisionLabel(title: "Title")
    }
}
