import UIKit

class Note {
    var left: Note?
    var right: Note?
    var value: Int = 0

    init(left: Note? = nil,
         right: Note? = nil,
         value: Int) {
        self.left = left
        self.right = right
        self.value = value
    }
}

class BinarySearchTree {

    var rootNote: Note?

    func insert(_ value: Int) {
        self.bstInsertLogic(item: value,
                            sourceNode: self.rootNote)
    }

    private func bstInsertLogic(item: Int,
                                sourceNode: Note?) {
        let node = Note(value: item)
        if sourceNode == nil {
            self.rootNote = node
        }else {
            if sourceNode?.value ?? 0  > item,
               sourceNode?.left == nil {
                sourceNode?.left = node
            }
            if sourceNode?.value ?? 0 < item,
               sourceNode?.right == nil {
                sourceNode?.right = node
            }
            if sourceNode?.value ?? 0 > item,
               sourceNode?.left != nil {
                self.bstInsertLogic(item: item,
                                    sourceNode: sourceNode?.left)
            }
            if sourceNode?.value ?? 0 < item,
               sourceNode?.right != nil {
                self.bstInsertLogic(item: item,
                                    sourceNode: sourceNode?.right)
            }
        }
    }

    func inorder() {
        self.inorderRec(sourceNode: self.rootNote)
    }

    func postorder() {
        self.postOrderRec(sourceNode: self.rootNote)
    }

    func preorder() {
        self.preOrderRec(sourceNode: self.rootNote)
    }

    //Inorder => Left, Root, Right.
    func inorderRec(sourceNode: Note?) {
        if sourceNode == nil {
            return
        }
        if sourceNode?.left != nil {
            self.inorderRec(sourceNode: sourceNode?.left)
        }
        print("PrintItem: \(sourceNode?.value ?? 0)")
        if sourceNode?.right != nil {
            self.inorderRec(sourceNode: sourceNode?.right)
        }
    }

    //Post order => Left, Right, Root.
    func postOrderRec(sourceNode: Note?) {
        if sourceNode == nil {
            return
        }
        if sourceNode?.right != nil {
            self.inorderRec(sourceNode: sourceNode?.right)
        }
        if sourceNode?.left != nil {
            self.inorderRec(sourceNode: sourceNode?.left)
        }
        print("PrintItem: \(sourceNode?.value ?? 0)")

    }

    //Preorder => Root, Left, Right.
    func preOrderRec(sourceNode: Note?) {
        if sourceNode == nil {
            return
        }
        print("PrintItem: \(sourceNode?.value ?? 0)")
        if sourceNode?.left != nil {
            self.inorderRec(sourceNode: sourceNode?.left)
        }
        if sourceNode?.right != nil {
            self.inorderRec(sourceNode: sourceNode?.right)
        }
    }

    func delete(_ deleteItem: Int) {
        if let root = self.rootNote {
            if deleteItem == root.value {
                // Its root element We have to delete
                let leftNode = self.rootNote?.left
                self.rootNote = self.rootNote?.right
                var tempNode = self.rootNote
                while tempNode != nil {
                    tempNode = tempNode?.left
                    if tempNode?.left == nil {
                        tempNode?.left = leftNode
                        break
                    }
                }

            }else {
                self.deleteRec(source: root,
                               deleteItem: deleteItem)
            }
        }
    }

    func deleteRec(source: Note?,
                   deleteItem: Int) {
        let sourceValue = source?.value ?? 0
        if deleteItem == source?.left?.value {
            let leftItem = source?.left?.left
            let rightItem = source?.left?.right
            rightItem?.left = leftItem
            source?.left = rightItem
            return
        }
        if deleteItem == source?.right?.value {
            let leftItem = source?.right?.left //70
            let rightItem = source?.right?.right // 80
            rightItem?.left = leftItem
            source?.right = rightItem
            return
        }
        if deleteItem < sourceValue {
            self.deleteRec(source: source?.left,
                           deleteItem: deleteItem)
        }
        if deleteItem > sourceValue {
            self.deleteRec(source: source?.right,
                           deleteItem: deleteItem)
        }
    }
}


/* Let us create following BST
             50
          /     \
         30      70
        /  \    /  \
      20   40  60   80 */

let tree = BinarySearchTree()
       tree.insert(50);
       tree.insert(30);
       tree.insert(20);
       tree.insert(40);
       tree.insert(70);
       tree.insert(60);
       tree.insert(80);
// Print inorder traversal of the BST

//Inorder => Left, Root, Right.
//
//Preorder => Root, Left, Right.
//
//Post order => Left, Right, Root.

//print("inorder")
//tree.inorder()
////print("postOrder")
////tree.postorder();
////print("Preorder")
////tree.preorder();
//print("AfterDelete 40")
//tree.delete(40)
//tree.inorder()
//print("Inserted 40 and Deleted 30")
//tree.insert(40)
//tree.delete(30)
//tree.inorder()
//print("Deleted 20")
//tree.delete(20)
//tree.inorder()
//print("Deleted 70")
//tree.delete(70)
//tree.inorder()
//print("Deleted 70")
//tree.delete(60)
//tree.inorder()



       tree.insert(50);
       tree.insert(30);
       tree.insert(20);
       tree.insert(40);
       tree.insert(70);
       tree.insert(60);
       tree.insert(80);
tree.delete(50)
tree.inorder()

