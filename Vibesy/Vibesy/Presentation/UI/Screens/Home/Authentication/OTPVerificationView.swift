//
//  OTPVerification.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/10/24.
//

import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject var homePageCoordinator: HomePageCoordinator
    @EnvironmentObject var userPasswordModel: UserPasswordModel
    
    @State private var goNext: Bool = false
    // 1) Define a FocusState enum for each of the four fields
    private enum Field: Int, Hashable {
        case field1, field2, field3, field4
    }
    
    // 2) Add this @State for showing an alert (or handling submit)
    @State private var showAlert = false
    
    // 3) Add this computed property to check that all four fields are non‐empty
    private var allFieldsFilled: Bool {
        !code1.isEmpty && !code2.isEmpty && !code3.isEmpty && !code4.isEmpty
    }
    
    // 4) Four @State strings that hold each digit
    @State private var code1 = ""
    @State private var code2 = ""
    @State private var code3 = ""
    @State private var code4 = ""
    
    // 5) Four "previous value" states so we can detect backspace
    @State private var prevCode1 = ""
    @State private var prevCode2 = ""
    @State private var prevCode3 = ""
    @State private var prevCode4 = ""
    
    // 6) A single FocusState that tracks which field is currently active
    @FocusState private var focusField: Field?
    
    @State private var errorMessage: String = ""
    
    @State private var alertTitle: String?
    
    func resetFields() {
        code1 = ""
        code2 = ""
        code3 = ""
        code4 = ""
        
        focusField = .field1
    }
    
    func handleSubmit() {
        let otpString = (code1 + code2 + code3 + code4).trimmingCharacters(in: .whitespacesAndNewlines)
        
        userPasswordModel.verifyOTP(with: otpString) { result in
            if let status = try? result.get().status, status == "OK" {
                Task { @MainActor in
                    homePageCoordinator.push(page: .updatePasswordView)
                }
            } else if let response = try? result.get() {
                Task { @MainActor in
                    self.errorMessage = response.description
                    self.showAlert.toggle()
                }
            } else {
                Task { @MainActor in
                    self.errorMessage = "Unexpected error verifying OTP."
                    self.showAlert.toggle()
                }
            }
        }
    }
    
    func handleResend() {
        if let email = userPasswordModel.email {
            userPasswordModel.sendOTP(for: email) { result in
                if let status = try? result.get().status, let description = try? result.get().description,  status == "OK" {
                    Task { @MainActor in
                        self.showAlert.toggle()
                        self.alertTitle = "OTP Sent"
                        self.errorMessage = description
                    }
                } else if let response = try? result.get() {
                    Task { @MainActor in
                        self.errorMessage = response.description
                        self.showAlert.toggle()
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Unexpected error sending OTP to \(email)."
                        self.showAlert.toggle()
                    }
                }
            }
        }
        
    }
    
    /// Builds one of the four single‐digit TextFields
    /// - Parameters:
    ///   - text: Binding to the current box’s string
    ///   - prevText: Binding to that box’s “previous” string (to detect backspace)
    ///   - field: Which FocusState enum case this box is
    ///   - nextField: The FocusState case to move to if the user types a digit
    ///   - prevField: The FocusState case to move to if the user backspaces
    @ViewBuilder
    private func otpTextField(
        text: Binding<String>,
        prevText: Binding<String>,
        field: Field,
        nextField: Field?,
        prevField: Field?
    ) -> some View {
        TextField("", text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.title2)
            .focused($focusField, equals: field)
            .frame(width:  50, height:  50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .onChange(of: text.wrappedValue) {_, newValue in
                // 1) Filter out any non‐digits immediately
                let filtered = newValue.filter { $0.isNumber }
                if filtered != newValue {
                    // If the user pasted or typed a non‐digit, strip it out
                    text.wrappedValue = filtered
                }
                
                // 2) Make sure we only ever store at most one character
                if text.wrappedValue.count > 1 {
                    // If somehow the user pasted “12”, keep only the last character
                    text.wrappedValue = String(text.wrappedValue.last!)
                }
                
                // 3) If the new value is empty but the old (prevText) was non‐empty ⇒ user pressed Backspace
                if text.wrappedValue.isEmpty && !prevText.wrappedValue.isEmpty {
                    if let goTo = prevField {
                        // Move focus to previous box
                        focusField = goTo
                    }
                }
                // 4) If we now have exactly one digit, jump to the next field (or dismiss keyboard if none)
                else if text.wrappedValue.count == 1 {
                    if let goToNext = nextField {
                        focusField = goToNext
                    } else {
                        // On the last box, we can resign first‐responder
                        focusField = nil
                    }
                }
                
                // 5) Update prevText so that next time onChange can compare
                prevText.wrappedValue = text.wrappedValue
            }
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("OTP Verification")
                    .font(.abeezeeItalic(size: 26))
                    .lineSpacing(6)
                    .frame(width: 236, height: 60)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("OTP Verification")
                    .font(.abeezeeItalic(size: 26))
                    .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                    .padding(.top)
                Text("Enter the 4-digit verification code we sent to your email.")
                    .font(.abeezee(size: 14))
                    .opacity(0.8)
                    .frame(maxWidth: 280, maxHeight: 43)
                Text("If you don’t see the code in your inbox, please check your spam folder.")
                    .font(.abeezee(size: 14))
                    .opacity(0.8)
                    .frame(maxWidth: 280, maxHeight: 43)
                HStack(spacing: 12) {
                    // For each box, we call a helper that sets up the TextField + onChange logic
                    otpTextField(
                        text: $code1,
                        prevText: $prevCode1,
                        field: .field1,
                        nextField: .field2,
                        prevField: nil
                    )
                    otpTextField(
                        text: $code2,
                        prevText: $prevCode2,
                        field: .field2,
                        nextField: .field3,
                        prevField: .field1
                    )
                    otpTextField(
                        text: $code3,
                        prevText: $prevCode3,
                        field: .field3,
                        nextField: .field4,
                        prevField: .field2
                    )
                    otpTextField(
                        text: $code4,
                        prevText: $prevCode4,
                        field: .field4,
                        nextField: nil,
                        prevField: .field3
                    )
                }
                .padding()
                .onAppear {
                    focusField = .field1
                }
                .frame(maxWidth: .infinity, alignment: .center)
                HStack {
                    Text("OTP expires in 5 minutes")
                        .font(.abeezee(size: 14))
                        .opacity(0.8)
                    Spacer()
                    Button(
                        action: {
                            handleResend()
                        },
                        label: {
                            Text("Resend OTP")
                                .font(.abeezee(size: 14))
                                .opacity(0.8)
                        }
                    )
                }
                .padding(.bottom)
                
                Button(
                    action: {
                        handleSubmit()
                    },
                    label: {
                        Text("Submit")
                            .font(.custom("ABeeZee-Italic", size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .disabled(!allFieldsFilled)
                .frame(maxHeight: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.sandstone)
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .background(.white)
            .clipShape(
                .rect(
                    topLeadingRadius: 60,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 60
                )
            )
            .edgesIgnoringSafeArea(.bottom)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle ?? "An error has occurred"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK")) {
                    self.alertTitle = nil
                    resetFields()
                }
            )
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    .sandstone,
                    .goldenBrown,
                    .espresso
                ]), startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .navigationDestination(isPresented: $goNext) {
            UpdatePasswordView()
                .navigationBarBackButtonHidden()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .gesture(
            DragGesture().onChanged { _ in
                hideKeyboard()
            }
        )
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden()
        
    }
}

#Preview {
    OTPVerificationView()
}

