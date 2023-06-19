//
//  BGView.swift
//  AccessbilitySampleApp
//
//  Created by Ashish Awasthi on 18/05/23.
//

import SwiftUI

struct BGView: View {
    var body: some View {
        Rectangle().fill(.red)
            .ignoresSafeArea()
    }
}

struct BGView_Previews: PreviewProvider {
    static var previews: some View {
        BGView()
    }
}
