import UIKit

/* Read Tree item in vertilcal way left to right */

class TreeNode {
    var value: Int = 0
    var leftNote: TreeNode? = nil
    var rightNote: TreeNode? = nil
    init(value: Int, 
         leftNote: TreeNode? = nil,
         rightNote: TreeNode? = nil) {
        self.value = value
        self.leftNote = leftNote
        self.rightNote = rightNote
    }
}

class PairItem {
    var index: Int = 0
    var note: TreeNode?
    init(index: Int, note: TreeNode? = nil) {
        self.index = index
        self.note = note
    }
}

class ArrayQueqe {
    var list: [PairItem] = []
    func insertItem(pair: PairItem) {
        self.list.append(pair)
    }
    func poll() -> PairItem {
        let item = self.list[0]
        self.list.remove(at: 0)
       return item
    }

    var isEmpty: Bool {
        return self.list.isEmpty
    }
}

func readThreeNoteInVerticalLineLeftToRight(rootNote: TreeNode) -> [Int : [Int]] {
    var hashMap: [Int: [Int]] = [:]
//    var minIndex = 0
//    var maxIndex = 0
    var queue: ArrayQueqe = ArrayQueqe()
    queue.insertItem(pair: PairItem(index: 0, note: rootNote))
    while !queue.isEmpty  {
        let pollItem = queue.poll()
//        minIndex = min(pollItem.index, minIndex)
//        maxIndex = max(pollItem.index, maxIndex)
        var arrayItem: [Int]? = hashMap[pollItem.index]
        if arrayItem != nil {
            arrayItem?.append(pollItem.note?.value ?? 0)
            hashMap[pollItem.index] = arrayItem
        }else {
            hashMap[pollItem.index] = [pollItem.note?.value ?? 0]
        }

        if pollItem.note?.leftNote != nil {
            let pair = PairItem(index: pollItem.index - 1,
                                note: pollItem.note?.leftNote)
           // print("LIndex:\(pair.index), value: \(pair.note?.value)")
            queue.insertItem(pair: pair)
        }
        if pollItem.note?.rightNote != nil {
            let pair = PairItem(index: pollItem.index + 1,
                                note: pollItem.note?.rightNote)
           // print("RIndex:\(pair.index), value: \(pair.note?.value)")
            queue.insertItem(pair: pair)
        }
    }
    for key in hashMap.keys.sorted() {
        print("key: \(key) Value: \(hashMap[key] ?? [])")
    }
    return hashMap
}
//   3
//9      20
//   15      7


let leftNote1 = TreeNode(value: 9)
let leftNote2 = TreeNode(value: 15)
let rightNote2 = TreeNode(value: 7 )
let rightNote1 = TreeNode(value: 20, leftNote: leftNote2 , rightNote: rightNote2)
let rootNote1 = TreeNode(value: 3, leftNote: leftNote1, rightNote: rightNote1)

print("VerticalTreeList: \(readThreeNoteInVerticalLineLeftToRight(rootNote: rootNote1))")

//       3
//    9      8
//4      0 1      7
//    5       2
let fourLeft = TreeNode(value: 4)
let fiveLeft = TreeNode(value: 5)
let twoRight = TreeNode(value: 2)
let zeroRight = TreeNode(value: 0, leftNote: fiveLeft, rightNote: twoRight)
let oneLeftNote = TreeNode(value: 1)
let sevenRightNote = TreeNode(value: 7)
let nineleft = TreeNode(value: 9,
                        leftNote: fourLeft,
                        rightNote: zeroRight)
let eightRight = TreeNode(value: 8, leftNote: oneLeftNote , rightNote: sevenRightNote)
let rootNote = TreeNode(value: 3, leftNote: nineleft, rightNote: eightRight)

print("VerticalTreeList: \(readThreeNoteInVerticalLineLeftToRight(rootNote: rootNote))")




