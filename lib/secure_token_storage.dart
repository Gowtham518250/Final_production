import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart'
    show kDebugMode, debugPrint, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Which kind of account the active session belongs to. Owner and customer
/// accounts can share a numeric ID (different identity tables), so the role
/// decides which token is returned.
enum SessionRole { owner, customer }

/// Thrown when a stored record cannot be decrypted or authenticated.
/// The offending record is deleted before this is thrown, so callers should
/// treat it as "session lost, ask the user to sign in again".
class SecureStorageException implements Exception {
  final String message;
  const SecureStorageException(this.message);
  @override
  String toString() => 'SecureStorageException: $message';
}

class _KeyRef {
  final String id;
  final enc.Key key;
  const _KeyRef(this.id, this.key);
}

/// Session credential storage.
///
/// Design:
///  * Secrets live in the platform keystore (flutter_secure_storage) and are
///    additionally sealed with AES-256-GCM (authenticated encryption).
///  * Each record's storage slot name is bound as GCM associated data, so a
///    record copied into another slot (another user, another field) fails
///    authentication.
///  * Payload format: `v2.<keyId>.<iv>.<ciphertext+tag>`. The key ID travels
///    with the record, so key rotation is crash-safe: old and new records are
///    each decryptable at every moment.
///  * Everything used for scoping (user ID, role) comes from secure storage,
///    never from SharedPreferences.
///  * Key creation is serialized, and a lost/corrupt key is never silently
///    replaced: records that depended on it are purged explicitly.
class SecureTokenStorage {
  SecureTokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Record base names (scoped per user: `<base>_<userId>`).
  static const String _kToken = 'auth_token_enc';
  static const String _kTokenTime = 'auth_time_enc';
  static const String _kCustomerToken = 'customer_token_enc';
  static const String _kCustomerTokenTime = 'customer_time_enc';
  static const String _kRefreshToken = 'auth_refresh_enc';
  static const String _kUser = 'auth_user_enc';

  static const List<String> _recordBases = <String>[
    _kToken,
    _kTokenTime,
    _kCustomerToken,
    _kCustomerTokenTime,
    _kRefreshToken,
    _kUser,
  ];

  // Plain (unencrypted) session metadata, still in secure storage.
  static const String _kUserId = 'user_id';
  static const String _kRole = 'auth_role';

  // Key ring.
  static const String _kCurrentKeyId = 'aes_current_kid';
  static const String _kKeySlotPrefix = 'aes_key_';
  static const List<String> _legacyKeySlots = <String>[
    'aes_device_key',
    'aes_device_key_salt',
  ];

  static const String _format = 'v2';
  static const Duration _maxSessionAge = Duration(days: 7);

  // ---------------------------------------------------------------- keys --

  static Future<_KeyRef>? _currentKeyFuture;
  static final Map<String, enc.Key> _keyCache = <String, enc.Key>{};

  @visibleForTesting
  static void resetForTesting() {
    _currentKeyFuture = null;
    _keyCache.clear();
  }

  /// Serialized: concurrent callers share one in-flight future, so two
  /// callers can never generate two different keys.
  static Future<_KeyRef> _currentKey() async {
    final future = _currentKeyFuture ??= _loadOrCreateCurrentKey();
    try {
      return await future;
    } catch (_) {
      _currentKeyFuture = null;
      rethrow;
    }
  }

  static Future<_KeyRef> _loadOrCreateCurrentKey() async {
    // v1 used a single key and a never-used salt; v1 records are not
    // readable by v2, so drop the leftovers.
    for (final slot in _legacyKeySlots) {
      await _storage.delete(key: slot);
    }

    final kid = await _storage.read(key: _kCurrentKeyId);
    if (kid != null) {
      final key = await _readKey(kid);
      if (key != null) return _KeyRef(kid, key);

      // The pointer exists but its key is missing or corrupt. Everything
      // sealed with it is unrecoverable: say so, purge, start clean.
      _log('Current key $kid is unreadable; purging dependent records.');
      await _purgeAllRecords();
      await _storage.delete(key: '$_kKeySlotPrefix$kid');
      _keyCache.remove(kid);
    }
    return _createKey(makeCurrent: true);
  }

  static Future<enc.Key?> _readKey(String kid) async {
    final cached = _keyCache[kid];
    if (cached != null) return cached;
    final stored = await _storage.read(key: '$_kKeySlotPrefix$kid');
    if (stored == null) return null;
    try {
      final key = enc.Key.fromBase64(stored);
      if (key.bytes.length != 32) return null;
      _keyCache[kid] = key;
      return key;
    } catch (_) {
      return null;
    }
  }

  static Future<_KeyRef> _createKey({required bool makeCurrent}) async {
    final kid = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final key = enc.Key.fromSecureRandom(32);
    // Key first, pointer second: a crash between the two leaves an unused
    // key, never a pointer to nothing.
    await _storage.write(key: '$_kKeySlotPrefix$kid', value: key.base64);
    _keyCache[kid] = key;
    if (makeCurrent) {
      await _storage.write(key: _kCurrentKeyId, value: kid);
    }
    return _KeyRef(kid, key);
  }

  // -------------------------------------------------------- seal / unseal --

  static Uint8List _aad(String slot) => Uint8List.fromList(utf8.encode(slot));

  static Future<String> _seal(
    String slot,
    String plaintext, {
    _KeyRef? with_,
  }) async {
    final ref = with_ ?? await _currentKey();
    final iv = enc.IV.fromSecureRandom(12); // 96-bit nonce for GCM
    final encrypter = enc.Encrypter(enc.AES(ref.key, mode: enc.AESMode.gcm));
    final sealed = encrypter.encrypt(
      plaintext,
      iv: iv,
      associatedData: _aad(slot),
    );
    return '$_format.${ref.id}.${iv.base64}.${sealed.base64}';
  }

  /// Returns null for legacy/unknown formats (treated as "no session").
  /// Throws [SecureStorageException] if a v2 record fails authentication.
  static Future<String?> _unseal(String slot, String payload) async {
    final parts = payload.split('.');
    if (parts.length != 4 || parts[0] != _format) return null;

    final key = await _readKey(parts[1]);
    if (key == null) {
      throw const SecureStorageException('Encryption key for record not found');
    }
    try {
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(
        enc.Encrypted.fromBase64(parts[3]),
        iv: enc.IV.fromBase64(parts[2]),
        associatedData: _aad(slot),
      );
    } catch (e) {
      throw SecureStorageException('Record failed authentication ($slot)');
    }
  }

  // ------------------------------------------------------ scoped records --

  static Future<String?> _scopedSlot(String base) async {
    final userId = await getUserId();
    if (userId == null) return null;
    return '${base}_$userId';
  }

  static Future<String> _requireSlot(String base) async {
    final slot = await _scopedSlot(base);
    if (slot == null) {
      throw StateError('No authenticated user ID: call saveUserId() first.');
    }
    return slot;
  }

  static Future<void> _writeSecret(String base, String value) async {
    final slot = await _requireSlot(base);
    await _storage.write(key: slot, value: await _seal(slot, value));
  }

  /// null  -> nothing stored (or legacy record dropped).
  /// throws -> record was corrupt; it has been deleted.
  static Future<String?> _readSecret(String base) async {
    final slot = await _scopedSlot(base);
    if (slot == null) return null;
    final raw = await _storage.read(key: slot);
    if (raw == null || raw.isEmpty) return null;
    try {
      final plain = await _unseal(slot, raw);
      if (plain == null) await _storage.delete(key: slot); // legacy format
      return plain;
    } on SecureStorageException {
      await _storage.delete(key: slot);
      rethrow;
    }
  }

  static Future<void> _deleteSecret(String base) async {
    final slot = await _scopedSlot(base);
    if (slot != null) await _storage.delete(key: slot);
  }

  static bool _isRecordSlot(String slot) =>
      _recordBases.any((base) => slot == base || slot.startsWith('${base}_'));

  static Future<void> _purgeAllRecords() async {
    final all = await _storage.readAll();
    for (final slot in all.keys.where(_isRecordSlot)) {
      await _storage.delete(key: slot);
    }
  }

  // ------------------------------------------------------------ identity --

  static Future<void> saveUserId(int userId) async {
    if (userId <= 0) throw ArgumentError.value(userId, 'userId');
    await _storage.write(key: _kUserId, value: userId.toString());
  }

  static Future<int?> getUserId() async {
    final parsed = int.tryParse(await _storage.read(key: _kUserId) ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static Future<void> clearUserId() => _storage.delete(key: _kUserId);

  static Future<void> saveRole(SessionRole role) =>
      _storage.write(key: _kRole, value: role.name);

  static Future<SessionRole> getRole() async {
    final stored = await _storage.read(key: _kRole);
    return stored == SessionRole.customer.name
        ? SessionRole.customer
        : SessionRole.owner;
  }

  // -------------------------------------------------------------- tokens --

  /// Stores [token] and a timestamp (used for the client-side 7 day check).
  static Future<void> _saveTokenWithTime(
    String tokenBase,
    String timeBase,
    String token,
  ) async {
    await _writeSecret(tokenBase, token);
    await _writeSecret(
      timeBase,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  static Future<void> saveToken(String token) =>
      _saveTokenWithTime(_kToken, _kTokenTime, token);

  static Future<void> saveCustomerToken(String token) =>
      _saveTokenWithTime(_kCustomerToken, _kCustomerTokenTime, token);

  static Future<String?> getCustomerToken() => _readSecret(_kCustomerToken);

  static Future<String?> getOwnerToken() => _readSecret(_kToken);

  /// Returns the token for the active role. Never returns an owner JWT while
  /// a customer session is active (or vice versa).
  static Future<String?> getToken() async {
    return await getRole() == SessionRole.customer
        ? getCustomerToken()
        : getOwnerToken();
  }

  static Future<void> saveRefreshToken(String token) =>
      _writeSecret(_kRefreshToken, token);

  static Future<String?> getRefreshToken() => _readSecret(_kRefreshToken);

  /// True when a token exists for the active role and is younger than 7 days.
  /// This is a convenience check only; the server must still enforce expiry.
  static Future<bool> isSessionValid() async {
    try {
      final isCustomer = await getRole() == SessionRole.customer;
      final token = await (isCustomer ? getCustomerToken() : getOwnerToken());
      if (token == null || token.isEmpty) return false;

      final stamp = await _readSecret(
        isCustomer ? _kCustomerTokenTime : _kTokenTime,
      );
      final millis = int.tryParse(stamp ?? '');
      if (millis == null) return false;

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(millis),
      );
      // A negative age means the clock moved backwards: don't trust it.
      return !age.isNegative && age <= _maxSessionAge;
    } on SecureStorageException catch (e) {
      _log('isSessionValid: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------- user --

  static Future<void> saveUser(Map<String, dynamic> userData) =>
      _writeSecret(_kUser, json.encode(userData));

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _readSecret(_kUser);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      await _deleteSecret(_kUser);
      throw const SecureStorageException('Stored user record is malformed');
    }
  }

  static Future<String?> getUserEmail() async {
    final email = (await getUser())?['email']?.toString().trim();
    return (email == null || email.isEmpty) ? null : email;
  }

  // -------------------------------------------------------------- logout --

  /// Removes the current user's session records, role and user ID.
  /// The key ring is kept so other users' sessions on this device survive.
  static Future<void> clearAll() async {
    for (final base in _recordBases) {
      await _deleteSecret(base);
    }
    await _storage.delete(key: _kRole);
    await clearUserId(); // last, because the steps above need it
  }

  static Future<void> deleteToken() async {
    await _deleteSecret(_kToken);
    await _deleteSecret(_kTokenTime);
  }

  static Future<void> clearToken() => deleteToken();

  static Future<void> clearRefreshToken() => _deleteSecret(_kRefreshToken);

  // ------------------------------------------------------------ rotation --

  /// Crash-safe key rotation covering every user on the device.
  ///
  /// 1. Decrypt every record first; if any fails, abort with nothing changed.
  /// 2. Create the new key (the old one stays in place).
  /// 3. Re-seal each record under the new key ID. Each record carries its
  ///    own key ID, so a crash at any point leaves everything readable.
  /// 4. Flip the "current key" pointer, then delete the old key.
  ///
  /// Call it while no other storage write is in flight.
  static Future<void> rotateKey() async {
    final oldRef = await _currentKey();
    final all = await _storage.readAll();

    final plain = <String, String>{};
    for (final entry in all.entries) {
      if (!_isRecordSlot(entry.key) || entry.value.isEmpty) continue;
      final value = await _unseal(entry.key, entry.value);
      if (value != null) plain[entry.key] = value; // skip legacy-format junk
    }

    final newRef = await _createKey(makeCurrent: false);
    for (final entry in plain.entries) {
      await _storage.write(
        key: entry.key,
        value: await _seal(entry.key, entry.value, with_: newRef),
      );
    }

    await _storage.write(key: _kCurrentKeyId, value: newRef.id);
    _currentKeyFuture = Future<_KeyRef>.value(newRef);

    await _storage.delete(key: '$_kKeySlotPrefix${oldRef.id}');
    _keyCache.remove(oldRef.id);
    _log('Key rotated; re-sealed ${plain.length} records.');
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('SecureTokenStorage: $message');
  }
}
