import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Создаём окно
        window = UIWindow(windowScene: windowScene)
        
        // Создаём UITabBarController
        let tabBarController = UITabBarController()
        
        // Создаём контроллеры для каждой вкладки
        let personVC = PersonViewController()
        personVC.tabBarItem = UITabBarItem(title: "Person", image: UIImage(systemName: "person"), tag: 0)
        
        let eventsVC = EventsViewController()
        eventsVC.tabBarItem = UITabBarItem(title: "Events", image: UIImage(systemName: "list.dash.header.rectangle"), tag: 1)
        
        let startVC = StartViewController()
        startVC.tabBarItem = UITabBarItem(title: "Start", image: UIImage(systemName: "record.circle"), tag: 2)
        
        let rankVC = RankViewController()
        rankVC.tabBarItem = UITabBarItem(title: "Rank", image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 3)
        
        let storeVC = StoreViewController()
        storeVC.tabBarItem = UITabBarItem(title: "Store", image: UIImage(systemName: "star"), tag: 4)
        
        // Добавляем контроллеры в таб-бар
        tabBarController.viewControllers = [personVC, eventsVC, startVC, rankVC, storeVC]
        
        // Устанавливаем tabBarController как корневой контроллер
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }

    // Остальные методы SceneDelegate остаются без изменений
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
