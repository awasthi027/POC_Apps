import UIKit

class Note {
    var data: Int
    var left: Note?
    var right: Note?

    init(data: Int,
         left: Note? = nil,
         right: Note? = nil) {
        self.data = data
        self.left = left
        self.right = right
    }
}

class QueueNode<T> {
    var data: T
    var next: QueueNode?
    init(data: T, 
         next: QueueNode? = nil) {
        self.data = data
        self.next = next
    }
}

class Queue<T>{

    var head: QueueNode<T>?

    var tail: QueueNode<T>?

    func enque(data: T) {
        let newNode =  QueueNode(data: data)
        if self.head == nil {
            self.head = newNode
            self.tail = newNode
            return
        }
        self.tail?.next = newNode
        self.tail = newNode
    }

    func dequeue() -> QueueNode<T>? {
        if self.head == nil {
            return nil
        }
        let pollItem = head
        self.head = head?.next
        return pollItem
    }

    var isEmpty: Bool {
        return self.head == nil
    }
}


class BinaryTree {

    var root: Note?

    func insert(data: Int) {
        if let rootNote = self.root {
            self.insert(root: rootNote, data: data)
            return
        } else {
            self.root = Note(data: data)
        }
    }

    private func insert(root: Note,
                        data: Int) {
        let queue: Queue = Queue<Note>()
        queue.enque(data: root)

        while !queue.isEmpty {
            let newNode = Note(data: data)
            let dequeueItem = queue.dequeue()
            if let leftNode = dequeueItem?.data.left {
                queue.enque(data: leftNode)
            }else {
                dequeueItem?.data.left = newNode
                return
            }
            if  let rightNode = dequeueItem?.data.right {
                queue.enque(data: rightNode)
            }else {
                dequeueItem?.data.right = newNode
                return
            }
        }
    }

    func inorder() {
        self.inorderRec(root: self.root)
    }

    func inorderRec(root: Note?) {
        if root == nil {
            return
        }
        self.inorderRec(root: root?.left)
        print("Item: \(root?.data ?? 0)")
        self.inorderRec(root: root?.right)
    }

    func delete(data: Int) {
        if let root = self.root {
            if root.data == data {
                let leftItem = root.left
                let rightItem = root.right
                self.root = rightItem
                var tempNote = self.root
                while tempNote != nil {
                    if tempNote?.left == nil {
                        tempNote?.left = leftItem
                        break
                    }
                    tempNote = tempNote?.left
                }

                return
            }else {
                self.deleteRec(source: root, data: data)
            }
        }
    }

    func deleteRec(source: Note?,
                   data: Int) {
        if source?.left?.data == data {
            let deleteNote = source?.left
            source?.left = deleteNote?.right
            var tempNote = source
            while tempNote != nil {
                if tempNote?.left == nil {
                    tempNote?.left = deleteNote?.left
                    break
                }
                tempNote = tempNote?.left
            }
            return
        }else {
            if source?.left != nil {
                self.deleteRec(source: source?.left, data: data)
            }
        }
        if source?.right?.data == data {
            let deleteNote = source?.right
            source?.right = deleteNote?.right
            var tempNote = source
            while tempNote != nil {
                if tempNote?.left == nil {
                    tempNote?.left = deleteNote?.left
                    break
                }
                tempNote = tempNote?.left
            }
            return
        }
        else {
            if source?.right != nil {
                self.deleteRec(source: source?.right, data: data)
            }
        }
    }
}


/*
               1
             /   \
           2      3
         /   \    / \
        4     5  6   7
       / \  /   \
     8    9 10  11
 */

let bt = BinaryTree()
print("Inserting Items")
bt.insert(data: 1)
bt.insert(data: 2)
bt.insert(data: 3)
bt.insert(data: 4)
bt.insert(data: 5)
bt.insert(data: 6)
bt.insert(data: 7)
bt.insert(data: 8)
bt.insert(data: 9)
bt.insert(data: 10)
bt.insert(data: 11)
print("Inorder item:=========")
bt.inorder()

print("delete:==============1")
bt.delete(data: 1)
bt.inorder()

print("delete:======= 2")
bt.delete(data: 2)
bt.inorder()

print("delete:======= 3")
bt.delete(data: 3)
bt.inorder()


print("delete:======= 11")
bt.delete(data: 11)
bt.inorder()

print("delete:======= 11")
bt.delete(data: 10)
bt.inorder()
