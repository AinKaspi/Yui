import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let storageService = StorageService()
        let viewModel = WorkoutListViewModel(storageService: storageService)
        let cameraService = CameraService()
        let poseDetectionService = try! PoseDetectionService(delegate: nil) // Теперь nil допустим
        let poseProcessor = PoseProcessor()
        
        let rootViewController = WorkoutListViewController(
            viewModel: viewModel,
            cameraService: cameraService,
            poseDetectionService: poseDetectionService,
            poseProcessor: poseProcessor
        )
        
        let navigationController = UINavigationController(rootViewController: rootViewController)
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
}
