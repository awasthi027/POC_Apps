// The Swift Programming Language
// https://docs.swift.org/swift-book

@freestanding(expression)
macro buildDate() -> String =
  #externalMacro(module: "MyOwnMicroMacros", type: "BuildDateMacro")
