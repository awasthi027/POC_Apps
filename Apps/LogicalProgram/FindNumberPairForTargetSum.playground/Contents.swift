import UIKit

/*
In a technical interview, you've been given an array of numbers and you need to find a pair of numbers that are equal to the given target value. Numbers can be either positive, negative, or both. Can you design an algorithm that works in O(n)—linear time or greater?

let sequence = [8, 10, 2, 9, 7, 5]
let results = pairValues(sum: 11) = //returns (9, 2)

 2, 5, 7,8,9,10
//memoized version - O(n + d)

Logic: Keep inserting attends number in list and keep checking deference between sum and next number If deference exist in last attends number It means we can consider difference and current number as pair.

*/

func pairNumbersMemoized(sequence: [Int], sum: Int) -> (Int, Int) {

    var addends = Set<Int>()
    for a in sequence {
        let diff = sum - a
        if addends.contains(diff) { //O(1) - constant time lookup
            return (a, diff)
        }
        //store previously seen value
        else {
            addends.insert(a)
        }
    }

    return (0, 0)
}

print("Find pair: \(pairNumbersMemoized(sequence:[8, 10, 2, 9, 7, 5], sum: 11))")
print("Find pair: \(pairNumbersMemoized(sequence:[8, 10, 2, 9, 7, 5], sum: 13))")
print("Find pair: \(pairNumbersMemoized(sequence:[8, 10, 2, 9, 7, 5], sum: 16))")
print("Find pair: \(pairNumbersMemoized(sequence:[8, 10, 2, 9, 7, 5], sum: 15))")

//
//// Recurzive technique diffcult to debug
//
//public func fibRec(_ n: Int) -> Int {
//        if n < 2 {
//            return n
//        } else {
//            return fibRec(n-1) + fibRec(n-2)
//        }
// }
//
//debugPrint("Series: \(fibRec(7))")
//
//// Solve same issue with DP and
//
//func fibMemoizedPosition(_ n: Int) -> Int {
//
//    var sequence: Array<Int> = [0, 1]
//    var results: Int = 0
//    var i: Int = sequence.count
//
//    //trivial case
//    guard n > i else {
//        return n
//    }
//
//    //all other cases..
//    while i <= n {
//        results = sequence[i - 1] + sequence[i - 2]
//        sequence.append(results)
//        i += 1
//    }
//
//    return results
//}
