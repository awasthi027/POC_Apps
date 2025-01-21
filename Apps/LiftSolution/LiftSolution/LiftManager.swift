//
//  ViewModel.swift
//  LiftSolution
//
//  Created by Ashish Awasthi on 15/01/25.
//

import Foundation

enum Direction {
    case up
    case down
    case unknown
}

protocol UserPreference: AnyObject {
    var floor: Int { get set }
    var direction: Direction { get set }
    var asignLift: LiftFeature?  { get set }
}

class User: UserPreference {
    var floor: Int = 0
    var direction: Direction = .unknown
    weak var asignLift: LiftFeature?
    init(floor: Int, direction: Direction) {
        self.floor = floor
        self.direction = direction
    }
}

enum LiftNumber {
    case first
    case second

    var name: String {
        switch self {
        case .first: return "First"
        case .second: return "Second"
        }
    }
}

protocol LiftFeature: AnyObject {
    var liftNumber: LiftNumber { get set }
    var currentFloor: Int { get set }
    var maxFloor: Int { get set }
    var minFloor: Int { get set }
    func moveUp(postion: Int)
    func moveDown(postion: Int)
    func asignUser(user: UserPreference)
}

class Lift: LiftFeature {

    var liftNumber: LiftNumber

    var currentFloor: Int = 0

    var maxFloor: Int = 16

    var minFloor: Int = 0

    var users: [UserPreference] = []

    

    init(liftNumber: LiftNumber) {
        self.liftNumber = liftNumber
    }

    func moveUp(postion: Int) {
        print("Moving Up from: \(self.currentFloor)")
        self.currentFloor = postion
        print("Moving Up To: \(self.currentFloor)")
    }

    func moveDown(postion: Int) {
        print("LeftName: \(self.liftNumber.name) Moving Down from: \(self.currentFloor)")
        self.currentFloor = postion
        print("LeftName: \(self.liftNumber.name) Moving Down To: \(self.currentFloor)")
    }

    func asignUser(user: UserPreference) {
        self.users.append(user)
    }
}

protocol MovingPosition {
    func pressUp(user:  UserPreference)
    func pressDown(user:  UserPreference)
}

class LiftManager: MovingPosition, ObservableObject {

    @Published var lifts: [LiftFeature] = []
    @Published var firstLiftPosition: Int = 0
    @Published var secondLiftPosition: Int = 0
    @Published var instructionStr: String = ""

    func addLeft(lift: LiftFeature) {
        print("Adding lift Name: \(lift.liftNumber.name)")
        self.lifts.append(lift)
    }

    func pressUp(user: UserPreference) {
        self.instructionStr = ""
        let newUser = user
        let nearByLift = self.findLeftNearBy(user: newUser)
        if user.floor == nearByLift.currentFloor {
            self.instructionStr = "Oh Oh I am on same floor"
            print("\(self.instructionStr)")
            return
        }
        if user.floor > nearByLift.maxFloor {
            self.instructionStr = "Oh Oh I am not supporting this floor: \(user.floor)"
            print("\(self.instructionStr)")
            return
        }
        nearByLift.asignUser(user: newUser)
        nearByLift.asignUser(user: user)
        let minDistance = abs(nearByLift.currentFloor - user.floor)
        if minDistance <= user.floor {
            self.keepMoving(direction: .up,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.moveUp(postion: user.floor)

        }else {
            self.keepMoving(direction: .down,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.moveDown(postion: user.floor)
        }
    }

    func pressDown( user: UserPreference) {
        self.instructionStr = ""
        let newUser = user
        let nearByLift = self.findLeftNearBy(user: newUser)
        if user.floor == nearByLift.currentFloor {
            self.instructionStr = "Oh Oh I am on same floor"
            print("\(self.instructionStr)")
            return
        }
        if user.floor < nearByLift.minFloor {
            self.instructionStr = "Oh Oh I am not supporting this floor: \(user.floor)"
            print("\(self.instructionStr)")
            return
        }
        nearByLift.asignUser(user: newUser)
        newUser.asignLift = nearByLift
        let minDistance = abs(nearByLift.currentFloor - user.floor)
        if minDistance < user.floor {
            self.keepMoving(direction: .up,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.moveUp(postion: user.floor)


        }else {

            self.keepMoving(direction: .down,
                            lift: nearByLift,
                            user: newUser)
            nearByLift.moveDown(postion: user.floor)
        }
    }

    func keepMoving(direction: Direction,
                    lift: LiftFeature,
                    user: UserPreference) {
        var currentFloor = lift.currentFloor
        if direction == .up {
            while currentFloor < user.floor {
                currentFloor += 1
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    switch lift.liftNumber {
                    case .first:
                        self.firstLiftPosition = currentFloor
                    case .second:
                        self.secondLiftPosition = currentFloor
                    }
                }
            }
        }else {
            while currentFloor > user.floor {
                currentFloor -= 1
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    switch lift.liftNumber {
                    case .first:
                        self.firstLiftPosition = currentFloor
                    case .second:
                        self.secondLiftPosition = currentFloor
                    }
                }
            }
        }

    }

    private func findLeftNearBy(user: UserPreference) -> LiftFeature {
        var sortAsNearBy: [(minDist:Int, lift:LiftFeature)] =  []
        for lift in self.lifts {
            let minDistance = abs(lift.currentFloor - user.floor)
            sortAsNearBy.append((minDistance, lift))
        }
        return sortAsNearBy.sorted(by: {  $0.minDist < $1.minDist }).first?.lift ?? Lift(liftNumber: .first)
    }

    func liftCurrentPostion(number: LiftNumber) -> Int {
        return self.lifts.filter {$0.liftNumber == number}.first?.currentFloor ?? 0
    }
}

