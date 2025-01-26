//
//  ContentView.swift
//  LiftSolution
//
//  Created by Ashish Awasthi on 15/01/25.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject var viewModel = ContentViewModel()
    @State private var sourceFloor: String = ""
    @State private var destinationFloor: String = ""
    @State private var liftMovingTowards: String = ""

    var body: some View {

        VStack(spacing: 20) {
            Spacer()

            TextField("Your floor", text: self.$sourceFloor)
                .keyboardType(.numberPad)
                .foregroundColor(.green)

            if self.sourceFloor.count > 0 {
                TextField("Enter Destination floor", text: self.$destinationFloor)
                    .keyboardType(.numberPad)
                    .foregroundColor(.green)
            }
            Button {
                let sourceFloor = Int(self.sourceFloor) ?? 0
                let destinationFloor = Int(self.destinationFloor) ?? 0
                if destinationFloor > sourceFloor {
                    self.liftMovingTowards = "UP"
                    self.viewModel.pressUp(user: User(sFloor: sourceFloor,
                                                    dFloor: destinationFloor,
                                                    direction: .up))
                } else {
                    self.liftMovingTowards = "DOWN"
                    self.viewModel.pressDown(user: User(sFloor: sourceFloor,
                                                                     dFloor: destinationFloor,
                                                                     direction: .up))
                }
                self.sourceFloor = ""
                self.destinationFloor = ""
            } label: {
                Text("Asign Lift")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                    .border(.green, width: 5)
            }
            .disabled(self.sourceFloor.count < 0 || self.destinationFloor.count < 0)
            Text("LIFT Moving: \(self.liftMovingTowards)")
                .foregroundColor(.orange)
                .font(.title)
            HStack {
                Text("\(self.viewModel.activeLift?.liftNumber.name ?? "") Lift Move ON: \(self.viewModel.activeLift?.currentFloor ?? 0)")
                    .foregroundColor(.orange)
                    .font(.callout)
            }
            Text("\(self.viewModel.instructionStr)")
                .font(.headline)
                .foregroundColor(.green)
            ForEach(self.viewModel.activeLifts, id: \.liftNumber) { lift in
                Text("Lift \(lift.liftNumber.name): \(lift.currentFloor)")
                    .foregroundColor(.red)
                    .font(.title)
            }
            Spacer()
        }
        .padding()
        .onAppear() {
            self.viewModel.addNewLift(lift: Lift(liftNumber: .first))
            self.viewModel.addNewLift(lift: Lift(liftNumber: .second))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
