/*
  Git smalled number from given number that number should have same digit as given number.
  Given a number n , find the smallest number that has the same set of digits as n and is greater than n. If n is the greatest possible number with its set of digits, then print “not possible”
     Step 1. find a number from postion which is lessthan most right postion number
     Step 2. Find the smallest digit on the right side of digits[i] that is larger than digits[i]
     Step 3. Swap iTh and Jith positio number.
     Steo 4. Sort from iTh postion to lenght in accending order
*/

func nextGreaterNumber(n: Int) -> String {
    var digits = Array(String(n))
    let length = digits.count

    // Step 1: Find the rightmost digit that is smaller than the digit next to it
    var i = length - 2
    while i >= 0 && digits[i] >= digits[i + 1] {
        i -= 1
    }
    print("idigit: \( digits[i])")
    // If no such digit is found, return "not possible"
    if i == -1 {
        return "not possible"
    }

    // Step 2: Find the smallest digit on the right side of digits[i] that is larger than digits[i]
    var j = length - 1
    while digits[j] <= digits[i] {
        j -= 1
    }
    print("Jdigit: \( digits[j])")
    print("digits: \(digits)")
    // Step 3: Swap digits[i] and digits[j]
    digits.swapAt(i, j)
    print("swapAtdigits: \( digits)")
    // Step 4: Sort the digits to the right of i in ascending order
    let sortedPart = digits[(i + 1)...].sorted()
    digits = Array(digits[0...(i)]) + sortedPart
    print("digits: \( digits)")
    return String(digits)
}

// Example usage
print("Resutl: \(nextGreaterNumber(n: 534976))")  // Output: 536479
print("Resutl: \(nextGreaterNumber(n: 129))")  // Output: 536479
