import UIKit

func findLonggedPressedCharaccterisSame(name: String,
                                        typped: String) -> Bool {
    var totalTyppedChar = typped.count
    var nameIndex: Int = 0
    var typedIndex: Int = 0
    let nameArray = Array(name)
    let typeArray = Array(typped)
    while typedIndex < totalTyppedChar {
       let nameChar = nameArray[nameIndex]
       let typeChar = typeArray[typedIndex]
        print("nameChar: \(nameChar), typeChar: \(typeChar)")
        if nameChar == typeChar {
            nameIndex += 1
            typedIndex += 1
        }else {
            typedIndex += 1
        }
        print("nameIndex: \(nameIndex), typedIndex: \(typedIndex)")
    }
    return nameIndex == name.count
}

print("\(findLonggedPressedCharaccterisSame(name: "alex", typped: "aaleex"))")
print("\(findLonggedPressedCharaccterisSame(name: "saeed", typped: "ssaaedd"))")
