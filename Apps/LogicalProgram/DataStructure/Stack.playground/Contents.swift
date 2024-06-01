import UIKit

class Node <T> {
    var data: T
    var link: Node<T>?
    init(data: T, link: Node<T>? = nil) {
        self.data = data
        self.link = link
    }
}

class Stack<T> {

    var top: Node<T>?
    var maxCount: Int = 11
    var count: Int = 0

    func push(_ data: T) {
        if self.maxCount == self.count {
            print("Stack overflow")
            return
        }
        let tempNode = Node(data: data)
        tempNode.link = top
        self.top = tempNode
        count += 1
    }

    func pop() -> Node<T>? {
        if self.top == nil {
            print("Stack underflow")
            return nil
        }
        let topNode = self.top
        self.top = self.top?.link
        self.count -= 1
        return topNode
    }

    var isEmpty: Bool {
        return self.top == nil
    }

    func peek() -> Node<T>? {
        if self.top == nil {
            print("Stack underflow")
            return nil
        }
        let topNode = self.top
        return topNode
    }

    func display() {
        if self.top == nil {
            print("Stack underflow")
            return
        }
        var tempNode = self.top
        while tempNode != nil {
            print("data: \(String(describing: tempNode?.data))")
            tempNode = tempNode?.link
        }
    }
}


//let queue = Stack<Int>()
//queue.push(1)
//queue.push(2)
//queue.push(2)
//queue.push(3)
//queue.push(4)
//queue.push(5)
//queue.push(6)
//queue.push(7)
//queue.push(8)
//queue.push(9)
//queue.push(10)
//queue.display()
//queue.pop()
//print("Display After pop item")
//queue.display()
//queue.push(11)
//queue.display()
//print("Display After pop item")
//queue.pop()
//queue.display()

let queue = Stack<String>()
queue.push("Test1")
queue.push("Test2")
queue.push("Test3")
queue.push("Test4")
queue.display()
print("PopItem: \(String(describing: queue.pop()?.data))")
print("PopItem: \(String(describing: queue.pop()?.data))")
print("PopItem: \(String(describing: queue.pop()?.data))")
print("PopItem: \(String(describing: queue.pop()?.data))")
