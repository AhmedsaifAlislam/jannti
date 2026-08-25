class SpiritualRank {
  final int level;
  final String title;
  final String description;
  final String icon;
  final int minDhikr;
  final int maxDhikr;

  const SpiritualRank({
    required this.level,
    required this.title,
    required this.description,
    required this.icon,
    required this.minDhikr,
    required this.maxDhikr,
  });
}

class SpiritualRanksData {
  static const List<SpiritualRank> allRanks = [
    SpiritualRank(
      level: 1,
      title: 'غَارِسٌ مُبْتَدِئ 🌱',
      description: 'بداية الغرس المبارك وتنوير الصحائف بذكر الله',
      icon: '🌱',
      minDhikr: 0,
      maxDhikr: 50,
    ),
    SpiritualRank(
      level: 2,
      title: 'مُسَبِّحٌ أَوَّاب 🌿',
      description: 'رطوبة اللسان بذكر الرحمن وتتابع الحسنات',
      icon: '🌿',
      minDhikr: 50,
      maxDhikr: 150,
    ),
    SpiritualRank(
      level: 3,
      title: 'سَاقِي الرِّيَاض 🍃',
      description: 'عناية مستمرة بغراس الجنان وتثبيت الأجور',
      icon: '🍃',
      minDhikr: 150,
      maxDhikr: 300,
    ),
    SpiritualRank(
      level: 4,
      title: 'زَارِعُ الفِرْدَوْس 🌴',
      description: 'بساتين ونخيل خضراء يانعة في واحة النعيم',
      icon: '🌴',
      minDhikr: 300,
      maxDhikr: 600,
    ),
    SpiritualRank(
      level: 5,
      title: 'خَازِنُ الأَنْوَار 💎',
      description: 'كنوز وجواهر مباركة مدخرة تحت ظل العرش',
      icon: '💎',
      minDhikr: 600,
      maxDhikr: 1000,
    ),
    SpiritualRank(
      level: 6,
      title: 'سَاكِنُ الجِنَان 🏡',
      description: 'بيوت ومنازل عامرة بالذكر في دار السلام',
      icon: '🏡',
      minDhikr: 1000,
      maxDhikr: 2000,
    ),
    SpiritualRank(
      level: 7,
      title: 'عَمَّارُ المَسَاجِد 🕌',
      description: 'صروح ومنابر من نور تشهد لصاحبها يوم القيامة',
      icon: '🕌',
      minDhikr: 2000,
      maxDhikr: 3500,
    ),
    SpiritualRank(
      level: 8,
      title: 'أَمِيرُ الفِرْدَوْس 🏰',
      description: 'قصور مشيدة وأنهار جارية في مقعد صدق',
      icon: '🏰',
      minDhikr: 3500,
      maxDhikr: 5000,
    ),
    SpiritualRank(
      level: 9,
      title: 'سَيِّدُ الذَّاكِرِين 🌟',
      description: 'منارات ذكر ساطعة تضيء لأهل السماء',
      icon: '🌟',
      minDhikr: 5000,
      maxDhikr: 7500,
    ),
    SpiritualRank(
      level: 10,
      title: 'صَاحِبُ السِّدْرَة 👑',
      description: 'قربٌ ورفعة عند سدرة المنتهى والمقام الرفيع',
      icon: '👑',
      minDhikr: 7500,
      maxDhikr: 10000,
    ),
    SpiritualRank(
      level: 11,
      title: 'وَلِيُّ الرَّحْمَن 🕊️',
      description: 'نور يسعى بين يديه وبأيمانه في يوم الجمع والخلود',
      icon: '🕊️',
      minDhikr: 10000,
      maxDhikr: 20000,
    ),
    SpiritualRank(
      level: 12,
      title: 'عَارِفٌ بِاللَّه 💫',
      description: 'معرفةٌ ويقينٌ تام وإقبالٌ دائم على طاعة الله',
      icon: '💫',
      minDhikr: 20000,
      maxDhikr: 50000,
    ),
    SpiritualRank(
      level: 13,
      title: 'صَاحِبُ المَقَامِ المَحْمُود 🌌',
      description: 'منابر من نور يغبطهم عليها النبيون والشهداء',
      icon: '🌌',
      minDhikr: 50000,
      maxDhikr: 100000,
    ),
    SpiritualRank(
      level: 14,
      title: 'نُورُ السَّمَاوَاتِ وَالأَرْض ☀️',
      description: 'المنزلة الكبرى الخالدة وأعلى درجات الفردوس الأعلى (100,000+ تسبيحة)',
      icon: '☀️',
      minDhikr: 100000,
      maxDhikr: 99999999,
    ),
  ];

  static SpiritualRank getCurrentRank(int totalDhikr) {
    for (final rank in allRanks.reversed) {
      if (totalDhikr >= rank.minDhikr) {
        return rank;
      }
    }
    return allRanks.first;
  }
}
