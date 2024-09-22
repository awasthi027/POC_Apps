import UIKit
/* Merging two sorted arrays into a single sorted array can be done efficiently using a two-pointer technique. Here's how you can do it in Swift:

Step-by-Step Solution
1.
Initialize two pointers to keep track of the current position in each array.
2.
Compare elements from both arrays and add the smaller element to the result array.
3.
Move the pointer of the array from which the element was taken.
4.
Continue until all elements from both arrays are processed */


func mergeSortedArrays(_ arr1: [Int], _ arr2: [Int]) -> [Int] {

    var sortedArray: [Int] = []
    var iIndex = 0
    var jIndex = 0
    while iIndex < arr1.count,
          jIndex < arr2.count {
        if arr1[iIndex] < arr2 [jIndex] {
            sortedArray.append(arr1[iIndex])
            iIndex += 1
        } else {
            sortedArray.append(arr2[jIndex])
            jIndex += 1
        }
    }
    while iIndex < arr1.count {
        sortedArray.append(arr1[iIndex])
        iIndex += 1
    }
    while jIndex < arr2.count {
        sortedArray.append(arr2[jIndex])
        jIndex += 1
    }
    return sortedArray
}

// Example usage
let array1 = [1, 3, 5, 7]
let array2 = [2, 4, 6, 8]
let result = mergeSortedArrays(array1, array2)
print(result)  // Output: [1, 2, 3, 4, 5, 6, 7, 8]
// This approach ensures that the merged array is sorted and has a time complexity of O(n + m)
