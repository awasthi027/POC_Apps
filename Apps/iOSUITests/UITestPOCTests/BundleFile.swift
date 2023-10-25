//
//  BundleFile.swift
//  WinDaddy
//  
//  Copyright © 2023 VUME Interactive Pvt. Ltd., All rights reserved. This product is protected
//  by copyright and intellectual property laws in the India and other
//  countries as well as by international treaties. For more info http://www.vume.in/.
//  

import Foundation

@propertyWrapper struct ReadBundleFile<DataType> {
    let name: String
    let type: String
    let fileManager: FileManager = .default
    let bundle: Bundle = .main
    let decoder: (Data) -> DataType

    var wrappedValue: DataType {
        guard let path = bundle.path(forResource: name, ofType: type) else { fatalError("Resource not found: \(name).\(type)") }
        guard let data = fileManager.contents(atPath: path) else { fatalError("Can not load file at: \(path)") }
        return decoder(data)
    }
}

@propertyWrapper
struct ReadBundleFileData<Value> {
    let name: String
    let type: String
    let defaultValue: Value?
    let fileManager: FileManager = .default
    let bundle: Bundle = .main

    var wrappedValue: Value? {
        guard let path = bundle.path(forResource: name, ofType: type) else { fatalError("Resource not found: \(name).\(type)") }
        guard let data = fileManager.contents(atPath: path) else { fatalError("Can not load file at: \(path)") }
        return data as? Value
    }
}

/*
// How to read
@BundleFile(name: "avatar", type: "jpg", decoder: { UIImage(data: $0)! } )
var avatar: UIImage


 @ReadBundleFileData(name: "homeBanners", type: "json", defaultValue: nil)
 var resultData: Data?
 
 */
