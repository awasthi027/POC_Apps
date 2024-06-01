import UIKit

var greeting = "Hello, playground"

/* Array contain number less than then the Array size example [1,2,3] Array length is 3 Array can't contain number more three It can't 4 number in list 

As program saying there will not be any item more than Index value Example arraycount is 3 then array will contain items lessthan 3
  Example: [1,3,3]
 index = 0 indexItem = 1 minus  1indexItem  1- 1 Update foundIndex = 1 value as -1
 [-1, 3, 3]
 index = 1 indexItem = 3 minus 1 indexItem  3- 1 Update foundIndex = 2 value as -3
 [-1, 3, -3]
 index = 2 indexItem = 3 minus 1 indexItem  3- 1 Update foundIndex = 2 there is minus value present
 its means It duplicate item
 Logic: If item repeat that calculate index will be same always, It will never changes
 [-1, 3, -3]

 */

func findDuplicateNumberFrom(list: [Int]) -> [Int] {
    var items: [Int] = list
    var duplicateNumber: [Int] = []
    for index in 0..<items.count  {
        let foundIndex = abs(items[index]) - 1
        let item = items[foundIndex]
        if item < 0 {
            duplicateNumber.append(abs(items[index]))
        }else {
            items[foundIndex] = -item
        }
    }
    print("Array: \(items)")
    return duplicateNumber
}

print("DuplicateNumber: \(findDuplicateNumberFrom(list:[1,2,3]))")
print("DuplicateNumber: \(findDuplicateNumberFrom(list:[1,2,2]))")
print("DuplicateNumber: \(findDuplicateNumberFrom(list:[1,3,3]))")
print("DuplicateNumber: \(findDuplicateNumberFrom(list:[3,4,3,2,5,6,2,8]))")
