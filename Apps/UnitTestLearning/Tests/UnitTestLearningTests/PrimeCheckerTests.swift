//
//  PrimeCheckerTests.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 24/09/24.
//

import Testing
import UnitTestLearning

enum Food {
    case burrito
    case taco
    case iceCream
}

struct FoodItem {
    var food: Food
    var quantity: Int
    init(food: Food, quantity: Int) {
        self.food = food
        self.quantity = quantity
    }
}
struct FoodTruck {

    var items: [FoodItem] = []
    static let isAvailable: Bool = true

    mutating func addFood(item: FoodItem) async {
        items.append(item)
    }

    func quantityOf(food: Food) -> Int {
        return  items.filter ({ $0.food == food}).first?.quantity ?? 0
    }
}

struct PrimeCheckerTests {

    let primeChecker = PrimeChecker.init()

    @Test func testIsPrime()  {
        #expect(primeChecker.isPrime(2) == true)
        #expect(primeChecker.isPrime(3) == true)
        #expect(primeChecker.isPrime(4) == false)
        #expect(primeChecker.isPrime(17) == true)
        #expect(primeChecker.isPrime(18) == false)
    }

    @Test(arguments: 0 ... 10)
    func test(index: Int) {
        #expect(index < 11)
    }

    @Test(arguments: [Food.burrito, .taco, .iceCream])
    func foodAvailable(food: Food) async {
        var foodTruck = FoodTruck()
        await foodTruck.addFood(item: FoodItem.init(food: food, quantity: 10))
        #expect(foodTruck.quantityOf(food: food) == 10)
    }

    @Test("The Food Truck has enough burritos",
          .enabled(if: FoodTruck.isAvailable))
    func foodAvailable() async throws {
        var foodTruck = FoodTruck()
        await foodTruck.addFood(item: FoodItem.init(food: .burrito, quantity: 20))
        #expect(foodTruck.quantityOf(food: .burrito) == 20)
    }
}
