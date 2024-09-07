import UIKit

class Node <T: Equatable> {
    var data: T
    var next: Node<T>?
    init(data: T,
         next: Node<T>? = nil) {
        self.data = data
        self.next = next
    }
}

public struct SingleLinkList <T: Equatable> {

    private var head: Node<T>?
    private var tail: Node<T>?
    public init() {}

    init(head: Node<T>?,
         tail: Node<T>?) {
        self.head = head
        self.tail = tail
    }

    mutating func insert(_ data: T) {
        let newNode = Node(data: data)
        if self.head == nil {
            self.head = newNode
            self.tail = newNode
        }else {
            self.tail?.next = newNode
            self.tail = newNode
        }
    }

    mutating func delete(_ data: T) {
        // This logic for head delete
        var tempNode = self.head
        if let noteData = tempNode?.data,
           noteData == data {
            self.head = tempNode?.next
            return
        }
        while(tempNode?.next != nil) {
            // this logic if tail delete
            if let noteData = self.tail?.data,
                noteData == data {
                self.tail = tempNode
            }
            // this is logic if mid item delete
            if let noteData = tempNode?.next?.data,
                noteData == data {
                tempNode?.next = tempNode?.next?.next
                break
            }
            tempNode = tempNode?.next
        }
    }

    func printResult() {
        var tempNode = self.head
        while(tempNode != nil) {
            if let data = tempNode?.data {
                print("dataItem: \(data)")
            }
            tempNode = tempNode?.next
        }
    }
}

var linkList = SingleLinkList<Float>()
linkList.insert(0.1)
linkList.insert(0.2)
linkList.insert(0.3)
linkList.insert(0.4)
print("Print Items: ======")
linkList.printResult()
linkList.delete(0.2)
linkList.delete(0.1)
linkList.delete(0.4)
linkList.insert(0.4)
linkList.insert(0.5)
linkList.insert(0.6)
print("Print Items: After Action")
linkList.printResult()
