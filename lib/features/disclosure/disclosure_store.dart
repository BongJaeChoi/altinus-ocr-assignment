abstract interface class DisclosureStore {
  Future<bool> hasAccepted();
  Future<void> accept();
}
