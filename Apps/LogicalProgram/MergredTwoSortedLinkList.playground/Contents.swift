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

     var head: Node<T>?
     var tail: Node<T>?
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


func mergeTwoSortedLinkList(firstLinkList: SingleLinkList<Float>, 
                            secondLinkList: SingleLinkList<Float>) {

    var sortedLinkList = SingleLinkList<Float>()
    var firstLinkListNote = linkListFirst.head
    var secondLinkListNote = secondLinkList.head

    while firstLinkListNote != nil,
            secondLinkListNote != nil {
        guard let firstData = firstLinkListNote?.data, 
                let secondData = secondLinkListNote?.data else {
            return
        }
        if firstData < secondData {
            sortedLinkList.insert(firstData)
            firstLinkListNote = firstLinkListNote?.next
        }else {
            sortedLinkList.insert(secondData)
            secondLinkListNote = secondLinkListNote?.next
        }
    }

    while firstLinkListNote != nil {
        sortedLinkList.insert(firstLinkListNote?.data ?? 0)
        firstLinkListNote = firstLinkListNote?.next
    }

    while secondLinkListNote != nil {
        sortedLinkList.insert(secondLinkListNote?.data ?? 0)
        secondLinkListNote = secondLinkListNote?.next
    }
    sortedLinkList.printResult()
}

var linkListFirst = SingleLinkList<Float>()
linkListFirst.insert(0.1)
linkListFirst.insert(0.3)
linkListFirst.insert(0.5)
linkListFirst.insert(0.7)

var linkListTwo = SingleLinkList<Float>()
linkListTwo.insert(0.2)
linkListTwo.insert(0.4)
linkListTwo.insert(0.6)
linkListTwo.insert(0.8)

mergeTwoSortedLinkList(firstLinkList: linkListFirst,
                       secondLinkList: linkListTwo)
