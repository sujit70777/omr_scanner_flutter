/// Free-tier caps and IAP product ids. Change here when adjusting the offer.
class PremiumConfig {
  PremiumConfig._();

  /// Must match the product id created in Play Console + App Store Connect.
  static const String premiumProductId = 'premium_unlock';

  static const int freeExamLimit = 1;
  static const int freeScansPerMonth = 20;

  static const List<String> premiumBullets = [
    'Unlimited exams',
    'Unlimited sheet scans',
    'Exam grading settings (multi-mark, partial answers, scoring)',
    'Excel & PDF export',
  ];
}
