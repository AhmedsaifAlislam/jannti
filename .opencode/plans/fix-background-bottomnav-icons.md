# خطة التعديلات — إصلاح الخلفية، تداخل BottomNav، وأيقونات الأذكار

## الملفات المستهدفة

### 1. `lib/screens/garden_screen.dart` — إصلاح الخلفية البانورامية

**المشكلة**: `_buildBackground()` تُرجع `Row` بدون `Positioned` داخل Stack، فلا تملأ مساحة العالم عامودياً.

**التعديل**:
- لف `_buildBackground()` داخل `Positioned.fill`
- تغيير `BoxFit.fill` → `BoxFit.cover`

```diff
  Widget _buildBackground() {
-   return Row(
-     children: List.generate(12, (_) =>
-       Expanded(
-         child: Image.asset(
-           GardenAssets.background,
-           fit: BoxFit.fill,
-         ),
-       ),
-     ),
-   );
+   return Positioned.fill(
+     child: Row(
+       children: List.generate(12, (_) =>
+         Expanded(
+           child: Image.asset(
+             GardenAssets.background,
+             fit: BoxFit.cover,
+           ),
+         ),
+       ),
+     ),
+   );
  }
```

---

### 2. `lib/screens/garden_screen.dart` — إصلاح تداخل BottomNav

**التعديلات**:

```diff
  padding: EdgeInsets.only(
-   bottom: MediaQuery.of(context).padding.bottom + 80,
+   bottom: MediaQuery.of(context).padding.bottom + 100,
  ),
```

```diff
  Widget _buildFab() {
    return Positioned(
-     bottom: 20,
+     bottom: 110,
      left: 20,
    );
  }
```

---

### 3. `lib/screens/dhikr_counter_screen.dart` — تكبير الأيقونات إلى 80×80

**الموقع الأول — `_buildTopBar`:**
```diff
  Image.asset(
    GardenAssets.getIconAsset(widget.dhikr.rewardType),
-   width: 60, height: 60,
+   width: 80, height: 80,
    fit: BoxFit.contain,
  ),
```

**الموقع الثاني — `_buildCounterSection`:**
```diff
  Image.asset(
    GardenAssets.getIconAsset(widget.dhikr.rewardType),
-   width: 60, height: 60,
+   width: 80, height: 80,
    fit: BoxFit.contain,
  ),
```

---

## التحقق بعد التنفيذ
1. `flutter analyze` — لا أخطاء أو تحذيرات
2. `flutter run` — اختبار يدوي
3. التأكد من: الخلفية تغطي كامل العالم، FAB لا يختفي خلف BottomNav، BottomNav لا يغطي محتوى جنتي
