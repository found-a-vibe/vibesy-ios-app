//
//  TabBarVisibilityCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/2/25.
//

import SwiftUI

struct TabBarVisibilityCoordinator: UIViewControllerRepresentable {
    @Binding var isTabBarVisible: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            self.updateTabBarVisibility()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            self.updateTabBarVisibility()
        }
    }

    private func updateTabBarVisibility() {
        if let tabBarController = findTabBarController() {
            isTabBarVisible = !tabBarController.tabBar.isHidden
        }
    }

    private func findTabBarController() -> UITabBarController? {
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        // Traverse down the view controller hierarchy to find UITabBarController
        var currentVC: UIViewController? = rootViewController
        while let presentedVC = currentVC?.presentedViewController {
            currentVC = presentedVC
        }

        return currentVC as? UITabBarController ?? currentVC?.children.first(where: { $0 is UITabBarController }) as? UITabBarController
    }
}

class TabBarVisibilityModel: ObservableObject {
    @Published var isTabBarVisible: Bool = true
}
