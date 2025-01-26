//
//  ContentViewModel.swift
//  LiftSolution
//
//  Created by Ashish Awasthi on 26/01/25.
//

import Foundation
protocol LiftManagerProtocol {
    func addNewLift(lift: Lift)
}

class ContentViewModel: ObservableObject,
                        LiftManagerProtocol,
                        MovingPosition { 
    @Published var instructionStr: String = ""
    @Published var activeLift: LiftFeature?
    @Published var activeLifts: [LiftFeature] = []

    var liftManager: LiftManager = LiftManager()
    
    func addNewLift(lift: Lift) {
        self.liftManager.delegate = self
        self.liftManager.addLeft(lift: lift)
    }

    func pressUp(user:  UserPreference) {
        self.liftManager.pressUp(user: user)
    }

    func pressDown(user:  UserPreference) {
        self.liftManager.pressDown(user: user)
    }

    var lifts: [LiftFeature] {
        return self.liftManager.lifts
    }
}

extension ContentViewModel: ChangeLiftPosition {
    func updateInstruction(instruction: String) {
        self.instructionStr = instruction
    }

    func changeLiftPosition(lift: any LiftFeature) {
        self.activeLift = lift
        guard let findLift = self.activeLifts.filter({$0.liftNumber == lift.liftNumber}).first else {
            self.activeLifts.append(lift)
            return
        }
        self.activeLifts = self.activeLifts.filter { $0.liftNumber != findLift.liftNumber}
        self.activeLifts.append(lift)
    }
}
