//
//  ContentView.swift
//  ChatTour
//
//  Created by Christian Wyglendowski on 9/12/24.
//

import Combine
import ConvexMobile
import SwiftUI

let client = ConvexClient(deploymentUrl: "https://sensible-elephant-70.convex.cloud")

struct ContentView: View {
  @State private var messages: [Message] = []
  @State private var cancellationHandle: Set<AnyCancellable> = []
  @State private var outgoing: String = ""
  var body: some View {
    return VStack {
      List {
        ForEach(messages) { message in
          Text(message.body)
        }
      }.task {
        try! await client.subscribe(name: "messages:list")
          .replaceError(with: [Message(id: "id", author: "None", body: "None")])
          .receive(on: DispatchQueue.main)
          .assign(to: \.messages, on: self)
          .store(in: &cancellationHandle)
      }
      .padding()
      HStack {
        TextField("", text: $outgoing)
          .border(.secondary)
        Button(action: {
          Task {
            let x: Message? = try await client.mutation(
              name: "messages:send", args: ["author": "iOS User", "body": outgoing])
            outgoing = ""
          }
        }) {
          Text("Send")
        }

      }
    }
  }
}

struct Message: Identifiable, Decodable {
  let id: String
  let author: String
  let body: String

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case author
    case body
  }
}

#Preview {
  ContentView()
}
