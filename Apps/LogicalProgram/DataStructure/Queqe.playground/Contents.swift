import UIKit

class Node {
    var nextNode: Node?
    var value: Int
    init(nextNode: Node? = nil, 
         value: Int) {
        self.nextNode = nextNode
        self.value = value
    }
}

class Queue {

    private var head: Node?
    private var tail: Node?

    public func enqueueItem(item: Int) {
        let tempNode = Node(value: item)
        if head == nil {
            self.head = tempNode
            self.tail = tempNode
        }else {
            /* Here head and tail are same note means same reference
             Now you are referencing tail next as new Item It will reference in head also
             changing tail as new item now new item will old new Item next and keep going
             Its is classical example of class referening
             Its means it
             */
            self.tail?.nextNode = tempNode
            self.tail = tempNode
        }
    }

    public func dequeue() ->Int {
        if self.head == nil {
            return 0
        }
        let item = self.head
        self.head = item?.nextNode
        return item?.value ?? 0
    }

    public var isEmpty: Bool {
        return self.head == nil
    }
}

let queue = Queue()
queue.enqueueItem(item: 10)
queue.enqueueItem(item: 20)
queue.enqueueItem(item: 30)

print("DequeueItem: \(queue.dequeue())")
print("DequeueItem: \(queue.dequeue())")
print("DequeueItem: \(queue.dequeue())")
queue.enqueueItem(item: 50)
queue.enqueueItem(item: 60)
queue.enqueueItem(item:  40)
print("DequeueItem: \(queue.dequeue())")
print("DequeueItem: \(queue.dequeue())")
print("DequeueItem: \(queue.dequeue())")
