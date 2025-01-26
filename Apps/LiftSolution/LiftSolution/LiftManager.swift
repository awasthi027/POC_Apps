//
//  ViewModel.swift
//  LiftSolution
//
//  Created by Ashish Awasthi on 15/01/25.
//

import Foundation
import SwiftUICore
import UIKit

enum Direction {
    case up
    case down
    case unknown
}

protocol UserPreference: AnyObject {
    var sFloor: Int { get set }
    var dFloor: Int { get set }
    var direction: Direction { get set }
}

class User: UserPreference {
    var sFloor: Int = 0
    var dFloor: Int = 0
    var direction: Direction = .unknown
    init(sFloor: Int,
         dFloor: Int,
         direction: Direction) {
        self.sFloor = sFloor
        self.dFloor = dFloor
        self.direction = direction
    }
}

enum LiftNumber {
    case first
    case second
    case third
    case fourth
    case fifth
    var name: String {
        switch self {
        case .first: return "First"
        case .second: return "Second"
        case .third: return "Third"
        case .fourth: return "Fourth"
        case .fifth: return "Fifth"
        }
    }
}

protocol LiftFeature: AnyObject {
    /// lift number
    var liftNumber: LiftNumber { get set }
    /// current floor of liff
    var currentFloor: Int { get set }
    /// supported max floor by lift
    var maxFloor: Int { get set }
    /// support minimum floor by lift
    var minFloor: Int { get set }
    /// Check the state of lift whether its moving or available for asign
    var isMoving: Bool { get set }

}

class Lift: LiftFeature {
    /// lift number
    var liftNumber: LiftNumber
    /// current floor of liff
    var currentFloor: Int = 0
    /// supported max floor by lift
    var maxFloor: Int = 16
    /// support minimum floor by lift
    var minFloor: Int = 0
    /// Check the state of lift whether its moving or available for asign
    var isMoving: Bool = false

    init(liftNumber: LiftNumber) {
        self.liftNumber = liftNumber
    }
}

protocol MovingPosition {
    func pressUp(user:  UserPreference)
    func pressDown(user:  UserPreference)
}

protocol ChangeLiftPosition: AnyObject {
    func changeLiftPosition(lift: LiftFeature)
    func updateInstruction(instruction: String)
}

class LiftManager: MovingPosition {

    var lifts: [Lift] = []

    weak var delegate: ChangeLiftPosition?

    func addLeft(lift: Lift) {
        print("Adding lift Name: \(lift.liftNumber.name)")
        self.lifts.append(lift)
    }

    func pressUp(user: UserPreference) {
        self.delegate?.updateInstruction(instruction:"")
        let newUser = user
        let nearByLift = self.findLeftNearBy(user: newUser)
        if user.dFloor == nearByLift.currentFloor {
            self.delegate?.updateInstruction(instruction: "Oh Oh I am on same floor")
            return
        }
        if user.dFloor > nearByLift.maxFloor {
            self.delegate?.updateInstruction(instruction: "Oh Oh I am not supporting this floor: \(user.dFloor)")
            return
        }
        self.delegate?.updateInstruction(instruction:  "\(nearByLift.liftNumber.name) LIFT Gate OPEN")
        let minDistance = abs(nearByLift.currentFloor - user.dFloor)
        if minDistance <= user.dFloor {
            nearByLift.isMoving = true
            self.keepMoving(direction: .up,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.isMoving = false
        }else {
            nearByLift.isMoving = true
            self.keepMoving(direction: .down,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.isMoving = false
        }
    }

    func pressDown( user: UserPreference) {
        self.delegate?.updateInstruction(instruction: "")
        let newUser = user
        let nearByLift = self.findLeftNearBy(user: newUser)
        if user.dFloor == nearByLift.currentFloor {
            self.delegate?.updateInstruction(instruction: "Oh Oh I am on same floor")
            return
        }
        if user.dFloor < nearByLift.minFloor {
            self.delegate?.updateInstruction(instruction: "Oh Oh I am not supporting this floor: \(user.dFloor)")
            return
        }
        self.delegate?.updateInstruction(instruction: "\(nearByLift.liftNumber.name) LIFT Gate OPEN")

        let minDistance = abs(nearByLift.currentFloor - user.dFloor)
        if minDistance < user.dFloor {
            nearByLift.isMoving = true
            self.keepMoving(direction: .up,
                            lift: nearByLift,
                            user: newUser)
        }else {
            nearByLift.isMoving = true
            self.keepMoving(direction: .down,
                            lift: nearByLift,
                            user: newUser)
        }
    }

    func keepMoving(direction: Direction,
                    lift: LiftFeature,
                    user: UserPreference) {
        if direction == .up {
            while lift.currentFloor < user.dFloor {
                lift.currentFloor += 1
                self.delegate?.changeLiftPosition(lift: lift)
            }

        }else {
            while lift.currentFloor > user.dFloor {
                lift.currentFloor -= 1
                self.delegate?.changeLiftPosition(lift: lift)
            }
        }
        lift.isMoving = false
    }

    private func findLeftNearBy(user: UserPreference) -> LiftFeature {
        // is Lift Available ON Requested Floor
        guard let nearbyLift = self.lifts.filter ({ $0.currentFloor == user.sFloor}).first else {
            var sortAsNearBy: [(minDist:Int, lift: LiftFeature)] =  []
            for lift in self.lifts {
                let minDistance = abs(lift.currentFloor - user.sFloor)
                sortAsNearBy.append((minDistance, lift))
            }
            let nearByLeft = sortAsNearBy.sorted(by: { $0.minDist < $1.minDist }).first?.lift ?? Lift(liftNumber: .first)
            nearByLeft.currentFloor = user.sFloor
            return nearByLeft
        }
        return nearbyLift
    }

    func liftCurrentPostion(number: LiftNumber) -> Int {
        return self.lifts.filter {$0.liftNumber == number}.first?.currentFloor ?? 0
    }
}

