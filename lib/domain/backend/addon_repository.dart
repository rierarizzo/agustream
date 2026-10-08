import 'addon.dart';

/// Reads the addons installed in the account.
///
/// Metadata for a title is not tied to one addon: like Nuvio does, it is looked
/// up across the enabled addons, so the UI needs the list to know where to ask.
abstract interface class AddonRepository {
  /// Enabled addons of the active profile, in the user's order.
  Future<List<Addon>> all();
}
