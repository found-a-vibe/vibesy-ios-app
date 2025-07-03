//
//  AuthenticationView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

struct AuthenticationView: View {
    @State var isSignIn = true
    
    var body: some View {
        if isSignIn {
            SignInView(isSignIn: $isSignIn)
        } else {
            SignUpView(isSignIn: $isSignIn)
        }
    }
}

#Preview {
    AuthenticationView()
}
