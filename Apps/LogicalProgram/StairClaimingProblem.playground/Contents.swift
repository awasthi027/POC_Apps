import UIKit


//1 >= n <= 54
// user can claim 1 or 2 step at time
// find the ways to claim destination with constraint user can take 1 or steps

/*

 Example: destination = 1, oneway only 1 Ans = 1
 destination = 2, oneway only 1 + 1, 2 Ans = 2
 destination = 3, oneway only 1 + 1 + , 2 + 1, 1 + 2  Ans = 3
 destination = 4, oneway only 1 + 1 + 1 + 1 , 2 + 2, 2 + 1 + 1, 1 + 2 + 1, 1 + 1 + 2  Ans = 5
 By this example, We can say as N increase number of step previous of two n

 */

func claimStairs(destination: Int) -> Int {
    if destination < 2 {
        return destination
    }
    var first = 1
    var second = 2
    var totalNumberStep = 0
    var startLoop = 3
    while startLoop <= destination {
      let steps = first + second
      first = second
      second = steps
      print("steps: \(steps)")
      totalNumberStep = steps
      print("totalNumberStep: \(totalNumberStep)")
      startLoop += 1
    }
    return totalNumberStep
}

print("\(claimStairs(destination: 10))")
