/// Uygulamayı kullanmak için gereken en düşük yaş.
const int kMinimumAge = 13;

/// [birth] tarihli kullanıcı [now] itibarıyla en az [kMinimumAge] yaşında mı?
bool isOldEnough(DateTime birth, {DateTime? now}) {
  return !birth.isAfter(latestAllowedBirthDate(now: now));
}

/// İzin verilen en geç doğum tarihi (bugünden tam [kMinimumAge] yıl önce).
DateTime latestAllowedBirthDate({DateTime? now}) {
  final n = now ?? DateTime.now();
  return DateTime(n.year - kMinimumAge, n.month, n.day);
}
