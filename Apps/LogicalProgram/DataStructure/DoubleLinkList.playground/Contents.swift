import UIKit

class Node<T: Equatable> {
    var data: T
    var next: Node<T>?
    var prev: Node<T>?

    init(data: T,
         next:  Node<T>? = nil,
         prev: Node<T>? = nil) {
        self.data = data
        self.next = next
        self.prev = prev
    }
}

class DoubleLinkList <T: Equatable> {

    var head: Node<T>?
    var tail: Node<T>?

    public init() { /* No action */ }

    private init(head: Node<T>? = nil,
                 tail: Node<T>? = nil) {
        self.head = head
        self.tail = tail
    }

    func insert(_ data: T) {
       let newNode = Node(data: data)
        if self.head == nil {
            self.head = newNode
            self.tail = newNode
        }else {
            newNode.prev = self.tail
            self.tail?.next = newNode
            self.tail = newNode
        }
    }

    func remove(_ data: T) {
        // If item matching with head
        if self.head?.data == data {
            self.head = self.head?.next
            self.head?.prev = nil
            return
        }

        var temp = self.head
        while temp?.next != nil {
            // If item matching with tail
            if self.tail?.data == data {
                self.tail = tail?.prev
                self.tail?.next = nil
                break
            }
            if temp?.next?.data == data {
                temp?.next?.next?.prev = temp
                temp?.next = temp?.next?.next
                break
            }
            temp = temp?.next
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

    func reverseItem() {
        var tempNode = self.tail
        while(tempNode != nil) {
            if let data = tempNode?.data {
                print("dataItem: \(data)")
            }
            tempNode = tempNode?.prev
        }
    }
}

let doubleLinkList = DoubleLinkList<Float>()

doubleLinkList.insert(0.1)
doubleLinkList.insert(0.2)
doubleLinkList.insert(0.3)
doubleLinkList.insert(0.4)
doubleLinkList.insert(0.5)
doubleLinkList.insert(0.6)
print("Print Items: ======")
doubleLinkList.printResult()
print("Reverse Items: ====")
doubleLinkList.reverseItem()

print("Removed Second Item: ====")
doubleLinkList.remove(0.2)
doubleLinkList.printResult()
print("Reverse Items: ====")
doubleLinkList.reverseItem()

print("Removed first Item: ====")
doubleLinkList.remove(0.1)
doubleLinkList.printResult()
print("Reverse Items: ====")
doubleLinkList.reverseItem()

print("Removed last Item: ====")
doubleLinkList.remove(0.6)
doubleLinkList.printResult()
print("Reverse Items: ====")
doubleLinkList.reverseItem()

print("Removed Not available Item: ====")
doubleLinkList.remove(0.6)
doubleLinkList.printResult()
print("Reverse Items: ====")
doubleLinkList.reverseItem()
