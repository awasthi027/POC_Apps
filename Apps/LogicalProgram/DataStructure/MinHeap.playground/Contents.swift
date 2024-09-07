import UIKit

struct MinHeap<T: Comparable> {
    var items: [T] = []

    //Get Index
    private func getLeftChildIndex(_ parentIndex: Int) -> Int {
        return (2 * parentIndex) + 1
    }
    private func getRightChildIndex(_ parentIndex: Int) -> Int {
        return (2 * parentIndex) + 2
    }
    private func getParentIndex(_ childIndex: Int) -> Int {
        return (childIndex - 1) / 2
    }

    // Boolean Check
    private func hasLeftChild(_ index: Int) -> Bool {
        return getLeftChildIndex(index) < items.count
    }
    private func hasRightChild(_ index: Int) -> Bool {
        return getRightChildIndex(index) < items.count
    }
    private func hasParent(_ index: Int) -> Bool {
        return getParentIndex(index) >= 0
    }

    // Return Item From Heap
    private func leftChild(_ index: Int) -> T {
        return items[getLeftChildIndex(index)]
    }
    private func rightChild(_ index: Int) -> T {
        return items[getRightChildIndex(index)]
    }
    private func parent(_ index: Int) -> T {
        return items[getParentIndex(index)]
    }

    mutating public func add(_ item: T) {
      items.append(item)
      heapifyUp()
    }


    public func peek() -> T {
      if items.count != 0 {
          return items[0]
      } else {
          fatalError()
      }
    }

    mutating public func poll() -> T {
      if items.count != 0 {
          let item = items[0]
          items[0] = items[items.count - 1]
          heapifyDown()
          items.removeLast()
          return item
      } else {
          fatalError()
      }
    }


    mutating private func heapifyUp() {
      var index = items.count - 1
      while hasParent(index) && parent(index) > items[index] {
          self.items.swapAt(getParentIndex(index), index)
          index = getParentIndex(index)
      }
    }

    mutating private func heapifyDown() {
      var index = 0
      while hasLeftChild(index) {
          var smallerChildIndex = getLeftChildIndex(index)
          if hasRightChild(index) && rightChild(index) < leftChild(index) {
              smallerChildIndex = getRightChildIndex(index)
          }
          if items[index] < items[smallerChildIndex] {
              break
          } else {
              self.items.swapAt(index, smallerChildIndex)
          }
          index = smallerChildIndex
      }
    }
}
var myHeap = MinHeap<Float>()

myHeap.add(1.0)
myHeap.add(10.0)
myHeap.add(8.0)
myHeap.add(9.0)
myHeap.add(7.0)
myHeap.add(3.0)
myHeap.add(4.0)

dump(myHeap.items)

print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
print("Peek Item: \(myHeap.poll())")
