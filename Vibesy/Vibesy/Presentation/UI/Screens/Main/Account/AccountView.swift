//
//  Account.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 11/18/24.
//

import SwiftUI

struct Tab: Codable, Hashable {
    var icon: String
    var title: String
    var destination: AccountPages?
}

struct AccountView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var accountPageCoordinator: AccountPageCoordinator
    
    func loadAccountTabs() -> [Tab]? {
        guard let url = Bundle.main.url(forResource: "tabs", withExtension: "json") else {
            print("JSON file not found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let accountTabs = try JSONDecoder().decode([Tab].self, from: data)
            return accountTabs
        } catch {
            print("Error decoding JSON: \(error)")
            return nil
        }
    }
    
    var body: some View {
        VStack {
            Text("Account")
                .font(.abeezeeItalic(size: 24))
                .foregroundStyle(.espresso)
                .frame(maxWidth: .infinity, alignment: .center)
            
            ForEach(loadAccountTabs()!, id: \.self) { tab in
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)
                    .frame(maxWidth: .infinity, maxHeight: 51)
                    .shadow(radius: 1)
                    .overlay {
                        HStack {
                            Image(tab.icon)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundStyle(.sandstone)
                                .padding(.trailing, 4)
                            Text(tab.title)
                                .foregroundStyle(.sandstone)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.sandstone)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        if tab.title == "Sign Out" {
                            userProfileModel.userProfile = UserProfile()
                            authenticationModel.signOut()
                        } else {
                            if let destination = tab.destination {
                                accountPageCoordinator.push(page: destination)
                            }
                        }
                    }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    AccountView()
}
