import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_update_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _morningAdhkar = true;
  bool _eveningAdhkar = true;
  bool _nightTahajjud = false;
  bool _fridayHour = true;
  bool _dailyGrowthReminder = true;

  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 30);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 30);

  Future<void> _selectTime(bool isMorning) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isMorning ? _morningTime : _eveningTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              surface: Color(0xFF0D2818),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isMorning) {
          _morningTime = picked;
        } else {
          _eveningTime = picked;
        }
      });
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03140C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2818).withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'مركز التنبيهات والأوراد 🔔✨',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Top Hero Card
            _buildHeroCard(),

            const SizedBox(height: 20),

            _buildSectionHeader('أوراد اليوم والليلة', Icons.wb_twilight),
            const SizedBox(height: 10),

            _buildReminderTile(
              title: 'تنبيه أذكار الصباح 🌅',
              subtitle: 'وقت التذكير: ${_morningTime.format(context)}',
              value: _morningAdhkar,
              onChanged: (v) => setState(() => _morningAdhkar = v),
              onTapTime: () => _selectTime(true),
            ),

            _buildReminderTile(
              title: 'تنبيه أذكار المساء 🌆',
              subtitle: 'وقت التذكير: ${_eveningTime.format(context)}',
              value: _eveningAdhkar,
              onChanged: (v) => setState(() => _eveningAdhkar = v),
              onTapTime: () => _selectTime(false),
            ),

            const SizedBox(height: 16),

            _buildSectionHeader('تنبيهات البركة والمواظبة', Icons.auto_awesome),
            const SizedBox(height: 10),

            _buildSimpleSwitchTile(
              title: 'تذكير نماء الجنة اليومي 🌱',
              subtitle: 'تنبيه لطيف إذا انقضى اليوم دون غرس شجرة جديدة',
              value: _dailyGrowthReminder,
              onChanged: (v) => setState(() => _dailyGrowthReminder = v),
            ),

            _buildSimpleSwitchTile(
              title: 'ساعة الاستجابة يوم الجمعة 🕌',
              subtitle: 'تذكير بالدعاء والصلاة على النبي ﷺ عصر الجمعة',
              value: _fridayHour,
              onChanged: (v) => setState(() => _fridayHour = v),
            ),

            _buildSimpleSwitchTile(
              title: 'تنبيه ثلث الليل والوتر 🌌',
              subtitle: 'إيقاظ للروح للاستغفار بالأسحار وركعة الوتر',
              value: _nightTahajjud,
              onChanged: (v) => setState(() => _nightTahajjud = v),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('تحديثات وإصدار التطبيق', Icons.system_update_rounded),
            const SizedBox(height: 10),

            _buildUpdateTile(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // 🤍 Pure White Card
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.notifications_active, color: Color(0xFF1B5E20), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'أورادٌ لا تنقطع وعمارةٌ للجنان',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2E18),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'اضبط تنبيهاتك لتكون من الذاكرين الله كثيراً والذاكرات',
                  style: TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReminderTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required VoidCallback onTapTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? const Color(0xFFFFD700).withValues(alpha: 0.4) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onTapTime,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'GESSTwo',
                          fontSize: 11,
                          color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeThumbColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFF2E7D32),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? const Color(0xFFFFD700).withValues(alpha: 0.4) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeThumbColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFF2E7D32),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.verified_outlined, color: Color(0xFFFFD700), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إصدار جنّتي المثبت',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'الإصدار: v${AppUpdateService.currentVersionName} (بناء ${AppUpdateService.currentVersionCode})',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 12,
                        color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                AppUpdateService().checkAndPromptUpdate(context, isManual: true);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF03140C)),
              label: const Text(
                'التحقق من وجود تحديثات الآن 🔄',
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03140C),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

