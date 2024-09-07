import UIKit

/*
 To find the smallest missing positive number from an array in O(n) time complexity and without using extra space, you can use an in-place algorithm. Here's a step-by-step approach:

 1.
 Place Each Positive Number in Its Correct Position: Iterate through the array and place each positive number x at the index x-1 if it is within the array bounds.
 2.
 Identify the Missing Positive Number: After rearranging, the first index that doesn't have the correct positive number indicates the smallest missing positive number

 // Example usage
 var nums = [3, 4, -1, 1]
 let missing = findMissingPositive(&nums)
 print("The smallest missing positive number is \(missing)")

 */

func findMissingPositive(_ nums: inout [Int]) -> Int {
    let n = nums.count
    for (index, item) in nums.enumerated() {
       // print("index: \(index), Item: \(item)")
        // If number already placed on Postion don't change: nums[index]  != index + 1
        // Don't change if number is greater than Array count However missing number will 1 to Array.count
        // Don't change postion of negitive number
        if item < nums.count, item > 0, nums[index]  != index + 1 {
            nums.swapAt(item, index)
        }
    }
   // print("Numbers: \(nums)")
    for index in 0..<n {
        if nums[index]  != index + 1 {
            return index + 1
        }
    }
    return 0
}

var nums = [3, 4, -1, 1]
let missing = findMissingPositive(&nums)
print("The smallest missing positive number is \(missing)")

nums = [2, 4, 3, -1]
let missing1 = findMissingPositive(&nums)
print("The smallest missing positive number is \(missing1)")
nums = [1, 2, 3, -1]
let missing2 = findMissingPositive(&nums)
print("The smallest missing positive number is \(missing2)")

/* Space complex city is o(n) and time complexcity is O(n) + n */
