//
//  ContentView.swift
//  ChatTour
//
//  Created by Christian Wyglendowski on 9/12/24.
//

import Auth0
import Combine
import ConvexAuth0
import ConvexMobile
import JWTDecode
import SwiftUI

let client = ConvexClientWithAuth(
  deploymentUrl: "https://sensible-elephant-70.convex.cloud", authProvider: Auth0Provider())

struct ContentView: View {
  @State private var viewModel = AuthViewModel()

  @ViewBuilder
  var body: some View {
    switch viewModel.authState {
    case .authenticated(let credentials):
      let userName = try? decode(jwt: credentials.idToken)["name"].string
      ChatView(viewModel: ChatViewModel(userName: userName ?? "unknown"))
    case .unauthenticated:
      LoginScreen(viewModel: viewModel)
    case .loading:
      ProgressView()
    }
  }
}

struct ChatView: View {
  @State private var viewModel: ChatViewModel

  init(viewModel: ChatViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    return VStack {
      HStack {
        Spacer()
        Button(action: {
          viewModel.logout()
        }) {
          Text("Logout \(viewModel.userName)")
        }
      }
      ScrollViewReader { scrollView in
        List {
          ForEach(viewModel.messages) { message in
            VStack(alignment: .leading) {
              Text(message.body)
              Text(message.author).font(.system(size: 12, weight: .light, design: .default))
            }.id(message.id)
          }
        }.onChange(of: viewModel.messages, initial: true) { oldMessages, newMessages in
          withAnimation {
            scrollView.scrollTo(newMessages.last?.id)
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

struct LoginScreen: View {
  @State private var viewModel: AuthViewModel

  init(viewModel: AuthViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    return VStack {
      Button(action: { viewModel.login() }) {
        Text("Login")
      }
    }
  }
}

@Observable class AuthViewModel {
  var authState: AuthState<Credentials> = .unauthenticated
  private var cancellationHandle: Set<AnyCancellable> = []

  init() {
    client.authState.replaceError(with: .unauthenticated)
      .receive(on: DispatchQueue.main)
      .assign(to: \.authState, on: self)
      .store(in: &cancellationHandle)
  }

  func login() {
    Task {
      await client.login()
    }
  }
}

@Observable class ChatViewModel {
  var messages: [Message] = []
  var outgoing: String = ""
  let userName: String
  private var cancellationHandle: Set<AnyCancellable> = []

  init(userName: String, messages: [Message]? = nil) {
    self.userName = userName
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
        name: "messages:send", args: ["author": userName, "body": outgoing])
      outgoing = ""
    }
  }

  func logout() {
    Task {
      await client.logout()
    }
  }
}

struct Message: Identifiable, Equatable, Decodable {
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
  let fakeData = ChatViewModel(
    userName: "iOS User",
    messages: [
      Message(id: "a", author: "Foo", body: "Hi!"),
      Message(id: "b", author: "Bar", body: "Hey there!"),
    ])
  ChatView(viewModel: fakeData)
}
