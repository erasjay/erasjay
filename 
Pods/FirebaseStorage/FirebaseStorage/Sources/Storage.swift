  open class func storage(app: FirebaseApp, url: String) -> Storage {
    if let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: app.container) {
      return provider.storage(for: Storage.bucket(for: app, urlString: url))
    } else {
      fatalError("StorageProvider instance not available")
    }
  private static func initFetcherServiceForApp(_ app: FirebaseApp,
                                               _ bucket: String,
                                               _ auth: AuthInterop?,
                                               _ appCheck: AppCheckInterop?)
      let authorizer = StorageTokenAuthorizer(
        googleAppID: app.options.googleAppID,
        fetcherService: fetcherService!,
        authProvider: auth, // AuthInterop is now optional and will be handled internally
        appCheck: appCheck  // AppCheckInterop is now optional and will be handled internally
      )
  private let auth: AuthInterop?
  private let appCheck: AppCheckInterop?
