//
//  ContentView.swift
//  SwizzlingPOC
//
//  Created by Ashish Awasthi on 18/11/24.
//

import SwiftUI

class Server {
    var clients: [Client] = []
    func add(client: Client) {
        clients.append(client)
    }
    
    deinit {
        print("\(Self.self) object was deallocated")
    }
}

class Client {
    var server: Server?
    init (server: Server) {
        self.server = server
        server.add(client: self) // memory leak
    }
    
    deinit {
        print("\(Self.self) object was deallocated")
    }
}

class SampleClass {
    var fullName: String = ""
    dynamic func original() {
        print("SwiftUI: I am the original")
    }
    
    dynamic func original_withParameters(for param1: String, param2: String) {
        print("SwiftUI: I am the original - param1: \(param1) - param2: \(param2)")
    }
    
    dynamic func original_withParameters_andReturnType(param: String) -> Int {
        print("SwiftUI: I am the original - param: \(param) - returnType: Int")
        return 1
    }
}

extension SampleClass {
    
    @_dynamicReplacement(for: original)
    func replacement() {
        let firstName = "Ashish"
        let lastName = "Awasthi"
        self.fullName = firstName + lastName
        print("SwiftUI: I'm just a replacement")
        [5, 8, 9, 10].filter { $0.isMultiple(of: 2) }.forEach { print("\($0)") }
    }
    
    @_dynamicReplacement(for: original_withParameters(for:param2:))
    func replacement_withParameters(param1: String, param2: String) {
        print("SwiftUI: I am the replacement - param1: \(param1) - param2: \(param2)")
    }
    
    @_dynamicReplacement(for: original_withParameters_andReturnType(param:))
    func replacement_withParameters_andReturnType(param: String) -> Int {
        print("SwiftUI: I am the replacement - param: \(param) - returnType: Int")
        return 2
    }
}

struct ContentView: View {
    
    var someObj: SampleClass = SampleClass()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear() {
            let sample = SampleClass()
            sample.original()
            sample.original_withParameters(for: "Param1", param2: "Param2")
            let _ = sample.replacement_withParameters_andReturnType(param: "Param1")
            
            let sut = Server()
            sut.add(client: Client(server: sut))
        }
    }
}

#Preview {
    ContentView()
}
