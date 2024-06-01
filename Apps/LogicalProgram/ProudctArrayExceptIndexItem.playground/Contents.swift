import UIKit

var greeting = "Hello, playground"
/* 
 Given dynamic array and you have calculate multiplication except i'th item

 Example: [2, 4, 5, 6]

 Output will be
 [120(4*5*6), 60([2* 5*6), 48(2*4*6), 40(2*4*5)]
 Tip: Item can be zero or positive and negitive

 */


func productListExceptSelfElement(list: [Int]) -> [Int] {
    var productArray: [Int] = []
    for indexLeft in 0..<list.count {
        var multiply: Int = 1
        for index in stride(from: 0, to: indexLeft, by: 1) {
            multiply = multiply * list[index]
        }
       // print("multiply1: \(multiply)")
        for index in stride(from: indexLeft + 1, to: list.count, by: 1) {
            multiply = multiply * list[index]
           // print("multiplyI: \(multiply)")
        }
        productArray.append(multiply)
    }
    return productArray
}

print("ProductArray: \(productListExceptSelfElement(list:  [2, 4, 5, 6]))")
print("ProductArray: \(productListExceptSelfElement(list:  [2, 4, 0, 6]))")
print("ProductArray: \(productListExceptSelfElement(list:  [2, 0, 0, 6]))")
print("ProductArray: \(productListExceptSelfElement(list:  [2, -2, 0, 0]))")

//[120(4*5*6), 60([2* 5*6), 48(2*4*6), 40(2*4*5)]

func productListExceptSelfElement2(list: [Int]) -> [Int] {

    var productArray: [Int] = []
    return productArray

}
