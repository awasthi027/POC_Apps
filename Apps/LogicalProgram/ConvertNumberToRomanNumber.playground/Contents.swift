import UIKit

enum RomanNumber: Int {
    case m = 1000
    case cm = 900
    case d = 500
    case cd = 400
    case c = 100
    case xc = 90
    case l = 50
    case xl = 40
    case x = 10
    case ix = 9
    case v = 5
    case iv = 4
    case i = 1

    var romanValue: String {
        switch self {
        case .m: return "M"
        case .cm: return "CM"
        case .d:  return "D"
        case .cd: return "CD"
        case .c:  return "C"
        case .xc: return "XC"
        case .l:  return "L"
        case .xl: return "XL"
        case .x:  return "X"
        case .v: return "V"
        case .ix: return "IX"
        case .iv:  return "IV"
        case .i:  return "I"
        }
    }
}

func convertNumberToRoman(number: Int) -> String {
    var romanNumber = ""
    var processsNumber = number
    var listItem: [RomanNumber] = [.m, .cm , .d, .cd, .c, .xc, .l, .xl, .x, .ix, .v, .iv,.i]
    for item in listItem {
        var reminder = processsNumber / item.rawValue
        while reminder > 0 {
            romanNumber.append(item.romanValue)
            reminder -= 1
        }
        processsNumber = processsNumber % item.rawValue
    }
    return romanNumber
}


print("\(convertNumberToRoman(number: 2944))")
print("\(convertNumberToRoman(number: 1000))")
print("\(convertNumberToRoman(number: 900))")
print("\(convertNumberToRoman(number: 500))")
print("\(convertNumberToRoman(number: 400))")
print("\(convertNumberToRoman(number: 100))")
print("\(convertNumberToRoman(number: 50))")
print("\(convertNumberToRoman(number: 40))")
print("\(convertNumberToRoman(number: 10))")
print("\(convertNumberToRoman(number: 9))")
print("\(convertNumberToRoman(number: 4))")
print("\(convertNumberToRoman(number: 1))")
print("\(convertNumberToRoman(number: 101))")
print("\(convertNumberToRoman(number: 105))")
print("\(convertNumberToRoman(number: 104))")
print("\(convertNumberToRoman(number: 106))")
print("\(convertNumberToRoman(number: 107))")
print("\(convertNumberToRoman(number: 108))")
print("\(convertNumberToRoman(number: 109))")
print("\(convertNumberToRoman(number: 110))")
