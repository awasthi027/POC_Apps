//
//  MovieListViewModel.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation

struct ListModel: Hashable {
    let id: String
    let text: String
}

class MovieListViewModel: ObservableObject {

    @Published var list: [ListModel] = []

    func publishListModel() {
        let states = (0..<50).map { ListModel(id: "\($0)", text: "Movie \($0)") }
        self.list = states
    }
}
