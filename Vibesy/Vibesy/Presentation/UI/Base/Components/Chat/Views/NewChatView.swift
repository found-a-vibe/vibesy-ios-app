//
//  NewChatView.swift
//  LivingFit
//
//  Created by Alexander Cleoni on 6/2/24.
//

import StreamChat
import StreamChatSwiftUI
import SwiftUI

struct NewChatView: View, KeyboardReadable {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    
    @SwiftUI.Environment(\.dismiss) var dismiss

    @Injected(\.fonts) var fonts
    @Injected(\.colors) var colors

    @StateObject var viewModel = NewChatViewModel()

    @Binding var isNewChatShown: Bool

    @State private var keyboardShown = false

    let columns = [GridItem(.adaptive(minimum: 120), spacing: 2)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack {
                    if !viewModel.selectedUsers.isEmpty {
                        LazyVGrid(columns: columns, alignment: .leading) {
                            ForEach(viewModel.selectedUsers) { user in
                                SelectedUserView(user: user)
                                    .onTapGesture(
                                        perform: {
                                            withAnimation {
                                                viewModel.userTapped(user)
                                            }
                                        }
                                    )
                            }
                        }
                    }

                    SearchUsersView(viewModel: viewModel)
                }
            }
            .padding()

            if viewModel.state != .channel {
//                CreateGroupButton(isNewChatShown: $isNewChatShown)
                UsersHeaderView()
            }

            if viewModel.state == .loading {
                VerticallyCenteredView {
                    ProgressView()
                }
            } else if viewModel.state == .loaded {
                List(viewModel.chatUsers.filter { user in
                    friendshipModel.friendList.contains { $0 == user.id }
                }) { user in
                    Button {
                        withAnimation {
                            viewModel.userTapped(user)
                        }
                    } label: {
                        ChatUserView(
                            user: user,
                            onlineText: viewModel.onlineInfo(for: user),
                            isSelected: viewModel.isSelected(user: user)
                        )
                        .onAppear {
                            viewModel.onChatUserAppear(user)
                        }
                    }
                }
                .listStyle(.plain)
            } else if viewModel.state == .noUsers {
                VerticallyCenteredView {
                    Text("No user matches these keywords")
                        .font(.title2)
                        .foregroundColor(Color(colors.textLowEmphasis))
                }
            } else if viewModel.state == .error {
                VerticallyCenteredView {
                    Text("Error loading the users")
                        .font(.title2)
                        .foregroundColor(Color(colors.textLowEmphasis))
                }
            } else if viewModel.state == .channel, let controller = viewModel.channelController {
                Divider()
                ChatChannelView(
                    viewFactory: CustomFactory.shared,
                    channelController: controller
                )
            } else {
                Spacer()
            }
        }
        .onAppear {
            if let currentUser = authenticationModel.state.currentUser {
                friendshipModel.fetchFriendList(userId: currentUser.id)
            }
        }
        .tint(.goldenBrown)
        .navigationTitle("New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButtonView() {
                    dismiss()
                }
            }
        }
        .onReceive(keyboardWillChangePublisher) { visible in
            keyboardShown = visible
        }
        .modifier(HideKeyboardOnTapGesture(shouldAdd: keyboardShown))
    }
}

struct SelectedUserView: View {

    @Injected(\.colors) var colors

    var user: ChatUser

    var body: some View {
        HStack {
            MessageAvatarView(
                avatarURL: user.imageURL,
                size: CGSize(width: 20, height: 20)
            )

            Text(user.name ?? user.id)
                .lineLimit(1)
                .padding(.vertical, 2)
                .padding(.trailing)
        }
        .background(Color(colors.background1))
        .cornerRadius(16)
    }
}

struct SearchUsersView: View {
    @Injected(\.colors) var colors
    @Injected(\.fonts) var fonts
    
    @StateObject var viewModel: NewChatViewModel

    var body: some View {
        HStack {
            Text("To:")
                .font(fonts.footnote)
                .foregroundColor(Color(colors.textLowEmphasis))
            TextField("Search", text: $viewModel.searchText)
            Button {
                if viewModel.state == .channel {
                    withAnimation {
                        viewModel.state = .loaded
                    }
                }
            } label: {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
            }
        }
    }
}

struct VerticallyCenteredView<Content: View>: View {

    var content: () -> Content

    var body: some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
    }
}

struct ChatUserView: View {

    @Injected(\.colors) var colors
    @Injected(\.fonts) var fonts

    var user: ChatUser
    var onlineText: String
    var isSelected: Bool

    var body: some View {
        HStack {
            LazyView(
                MessageAvatarView(avatarURL: user.imageURL)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name ?? user.id)
                    .lineLimit(1)
                    .font(fonts.bodyBold)
                Text(onlineText)
                    .font(fonts.footnote)
                    .foregroundColor(Color(colors.textLowEmphasis))
            }
            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .renderingMode(.template)
                    .foregroundColor(colors.tintColor)
            }
        }
    }
}

struct UsersHeaderView: View {

    @Injected(\.colors) var colors
    @Injected(\.fonts) var fonts

    var title = "Friends"

    var body: some View {
        HStack {
            Text(title)
                .padding(.horizontal)
                .padding(.vertical, 2)
                .font(fonts.body)
                .foregroundColor(Color(colors.textLowEmphasis))

            Spacer()
        }
    }
}

