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
  @State private var viewModel: ChatViewModel

  init(viewModel: ChatViewModel = ChatViewModel()) {
    self.viewModel = viewModel
  }

  var body: some View {
    return VStack {
      List {
        ForEach(viewModel.messages) { message in
          VStack(alignment: .leading) {
            Text(message.body)
            Text(message.author).font(.system(size: 12, weight: .light, design: .default))
          }
        }
      }

      HStack {
        TextField("", text: $viewModel.outgoing)
          .border(.secondary)
        Button(action: {
          viewModel.sendOutgoing()
        }) {
          Text("Send")
        }

      }
    }.padding()
  }
}

@Observable class ChatViewModel {
  var messages: [Message] = []
  var outgoing: String = ""
  private var cancellationHandle: Set<AnyCancellable> = []

  init(messages: [Message]? = nil) {
    if let providedMessages = messages {
      self.messages = providedMessages
    } else {
        try! client.subscribe(name: "messages:list")
          .replaceError(with: [Message(id: "id", author: "None", body: "None")])
          .receive(on: DispatchQueue.main)
          .assign(to: \.messages, on: self)
          .store(in: &cancellationHandle)
      }
  }

  func sendOutgoing() {
    Task {
      try await client.mutation(
        name: "messages:send", args: ["author": "iOS User", "body": outgoing])
      outgoing = ""
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
  let fakeData = ChatViewModel(messages: [
    Message(id: "a", author: "Foo", body: "Hi!"),
    Message(id: "b", author: "Bar", body: "Hey there!"),
  ])
  ContentView(viewModel: fakeData)
}
