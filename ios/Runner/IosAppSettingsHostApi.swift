import UIKit

final class IosAppSettingsHostApi: AppSettingsHostApi {
  typealias CanOpen = (URL) -> Bool
  typealias Opener = (URL, @escaping (Bool) -> Void) -> Void

  private let settingsURL: URL
  private let canOpen: CanOpen
  private let opener: Opener

  convenience init(application: UIApplication = .shared) {
    self.init(
      settingsURL: URL(string: UIApplication.openSettingsURLString)!,
      canOpen: application.canOpenURL,
      opener: { url, completion in
        application.open(url, options: [:], completionHandler: completion)
      }
    )
  }

  internal init(
    settingsURL: URL,
    canOpen: @escaping CanOpen,
    opener: @escaping Opener
  ) {
    self.settingsURL = settingsURL
    self.canOpen = canOpen
    self.opener = opener
  }

  func open(completion: @escaping (Result<Bool, Error>) -> Void) {
    let terminal = OneShotResult<Bool>()
    guard canOpen(settingsURL) else {
      terminal.deliver(.success(false), to: completion)
      return
    }

    opener(settingsURL) { didOpen in
      terminal.deliver(.success(didOpen), to: completion)
    }
  }
}
