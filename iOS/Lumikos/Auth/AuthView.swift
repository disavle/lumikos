import SwiftUI

struct AuthView: View {
    @Bindable var model: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.mode == .register {
                        TextField("Email", text: $model.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .accessibilityIdentifier(AXID.authEmail)
                        // .username tells iOS which field to save into Passwords together with the password.
                        TextField("Nickname", text: $model.nickname)
                            .textContentType(.username)
                            .accessibilityIdentifier(AXID.authNickname)
                    } else {
                        TextField("Email or nickname", text: $model.login)
                            .textContentType(.username)
                            .accessibilityIdentifier(AXID.authLogin)
                    }
                    // .newPassword makes iOS offer a strong password, .password offers saved ones.
                    SecureField("Password", text: $model.password)
                        .textContentType(model.mode == .register ? .newPassword : .password)
                        .accessibilityIdentifier(AXID.authPassword)
                } footer: {
                    if model.mode == .register {
                        Text("Nickname: 3–20 letters, digits or _. Password: at least 8 characters.")
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                Section {
                    Button {
                        Task { await model.submit() }
                    } label: {
                        HStack {
                            Text(model.mode == .login ? LocalizedStringKey("Log in") : "Sign up")
                            if model.isLoading { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(!model.canSubmit)
                    .accessibilityIdentifier(AXID.authSubmit)

                    // The ternary needs LocalizedStringKey, otherwise Swift picks String and the text is not translated.
                    Button(model.mode == .login ? LocalizedStringKey("No account yet? Sign up") : "Have an account? Log in") {
                        model.mode = model.mode == .login ? .register : .login
                    }
                    .accessibilityIdentifier(AXID.authSwitchMode)
                }
            }
            .navigationTitle("Lumikos")
        }
    }
}
