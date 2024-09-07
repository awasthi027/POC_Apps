import UIKit

func groupOfAnagrams(list: [String]) {

    var outputArray: [String: [String]] = [:]

    for item in list {
        let arrayItem = Array(item).sorted()
        let newKey = String(arrayItem)
        if var findItems = outputArray[newKey] {
            findItems.append(item)
            outputArray[newKey] = findItems
        }else {
            outputArray[newKey] = [item]
        }
    }
    print("\(outputArray.values)")
}

groupOfAnagrams(list: ["eat", "tea", "tan", "ate", "nat", "bat"])
