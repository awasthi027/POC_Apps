//
//  ContentView.swift
//  LiftSolution
//
//  Created by Ashish Awasthi on 15/01/25.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject  var manager = LiftManager()
    @State private var floorNumber: String = ""

    var body: some View {

        VStack(spacing: 20) {
            Spacer()

            TextField("Enter floor Number", text: self.$floorNumber)
                .keyboardType(.numberPad)
            HStack {
                Button("Up Arrow") {
                    self.manager.pressUp(user: User(floor: Int(self.floorNumber) ?? 0,
                                                    direction: .up))
                }
                Spacer()
                Button("Down Arrow") {
                    self.manager.pressDown(user: User(floor: Int(self.floorNumber) ?? 0,
                                                      direction: .up))
                }
            }
            HStack {
                Text("First Lift on floor: \(self.manager.firstLiftPosition)")
                Spacer()
                Text("First Lift on floor: \(self.manager.secondLiftPosition)")
            }
            Text("\(self.manager.instructionStr)")
            Spacer()
        }
        .padding()
        .onAppear() {
            self.manager.addLeft(lift: Lift(liftNumber: .first))
            self.manager.addLeft(lift: Lift(liftNumber: .second))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
