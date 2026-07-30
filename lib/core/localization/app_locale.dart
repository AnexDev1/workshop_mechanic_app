import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ValueNotifier<String> {
  static const _preferenceKey = 'app_language';
  static final AppLocaleController instance = AppLocaleController._();
  late SharedPreferences _preferences;

  AppLocaleController._() : super('en');

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    value = _preferences.getString(_preferenceKey) ?? 'en';
  }

  void setLanguage(String languageCode) {
    if (!const {'en', 'am', 'om'}.contains(languageCode) ||
        value == languageCode) {
      return;
    }
    value = languageCode;
    unawaited(_preferences.setString(_preferenceKey, languageCode));
  }

  Locale get materialLocale =>
      value == 'am' ? const Locale('am') : const Locale('en');
}

class AppLanguageScope extends InheritedNotifier<AppLocaleController> {
  const AppLanguageScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static void depend(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
  }
}

extension AppTranslation on BuildContext {
  String tr(String key, [Map<String, Object> values = const {}]) {
    AppLanguageScope.depend(this);
    var text = AppStrings.translate(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }
}

abstract final class AppStrings {
  static String translate(String key) {
    final language = AppLocaleController.instance.value;
    return _translations[language]?[key] ?? _translations['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'workshop': 'Workshop',
      'welcomeBack': 'Welcome back',
      'signInSubtitle': 'Sign in to manage your workshop shift',
      'username': 'Username',
      'enterUsername': 'Enter your username',
      'usernameRequired': 'Enter your username',
      'password': 'Password',
      'passwordRequired': 'Enter your password',
      'serverSettings': 'Server settings',
      'workshopServer': 'Workshop server',
      'serverRequired': 'Enter server URL',
      'continueToWorkshop': 'Continue to workshop',
      'shiftActive': 'Shift active',
      'offDuty': 'You’re off duty',
      'locationRecorded': 'Location recorded · ready for work',
      'checkInHint': 'Check in to begin your shift',
      'checkIn': 'Check in',
      'checkOut': 'Check out',
      'gettingGps': 'Getting GPS…',
      'sync': 'Sync',
      'syncing': 'Syncing',
      'online': 'Online',
      'offline': 'Offline',
      'pendingCount': '{count} pending',
      'myTasks': 'My tasks',
      'availablePool': 'Available pool',
      'all': 'All',
      'assigned': 'Assigned',
      'inProgress': 'In progress',
      'completed': 'Completed',
      'activeTask': 'ACTIVE TASK',
      'available': 'AVAILABLE',
      'waitingTask': 'Waiting for your next task',
      'workTimer': 'Work timer',
      'estimated': 'Estimated',
      'logged': 'Logged',
      'takeTask': 'Take this task',
      'startWork': 'Start work',
      'stopWorkTimer': 'Stop work timer',
      'complete': 'Complete',
      'requestMaterial': 'Request material',
      'requestOutsource': 'Request outsource',
      'noTasks': 'No tasks assigned',
      'retry': 'Retry',
      'todaySnapshot': 'TODAY’S SNAPSHOT',
      'navigation': 'NAVIGATION',
      'taskDashboard': 'Task dashboard',
      'taskDashboardSubtitle': 'Shift, tasks and sync',
      'myRequests': 'My requests',
      'requestsSubtitle': 'Materials and outsourcing',
      'working': 'WORKING',
      'idle': 'IDLE',
      'dailyEfficiency': 'Daily efficiency',
      'logout': 'Log out',
      'language': 'Language',
      'english': 'English',
      'amharic': 'አማርኛ',
      'oromo': 'Afaan Oromoo',
      'requestHubSubtitle': 'Track workshop support requests',
      'materials': 'Materials',
      'outsource': 'Outsource',
      'materialRequests': 'Material requests',
      'outsourceRequests': 'Outsource requests',
      'noMaterialRequests': 'No material requests',
      'noOutsourceRequests': 'No outsource requests',
      'newRequestsHint': 'New requests created from a task will appear here.',
      'unnamedRequest': 'Unnamed request',
      'jobNotSpecified': 'Workshop job not specified',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'pending': 'Pending',
      'submitted': 'Submitted',
      'draft': 'Draft',
      'refreshRequests': 'Refresh requests',
      'requestsLoadError':
          'Requests could not be updated. Check your connection and try again.',
      'turnOnLocation': 'Turn on location',
      'locationOffMessage':
          'Location is turned off. Turn it on to check in. Mobile data or Wi-Fi is not required.',
      'locationSettings': 'Location settings',
      'locationPermissionNeeded': 'Location permission needed',
      'locationPermissionMessage':
          'Allow location access so the app can record your check-in, even while offline.',
      'tryAgain': 'Try again',
      'allowLocation': 'Allow location access',
      'locationBlockedMessage':
          'Location access is blocked. Open app settings and allow location access to check in.',
      'appSettings': 'App settings',
      'cancel': 'Cancel',
      'noNetwork':
          'No network connection. Your changes are safe and remain queued.',
      'alreadyUpToDate': 'Data is already up to date.',
      'syncFailed':
          'Sync failed. Your pending changes are still saved locally.',
      'syncPermissionDenied':
          'Could not sync {action}: your account is not allowed to update duty logs. The action is still saved. Ask a workshop administrator to grant Technician Duty Log access.',
      'syncServerRejected':
          'The server rejected {action}. The action is still saved locally and can be retried.',
      'syncSuccess': 'Synced {count} pending action(s) successfully.',
      'syncPartial': 'Synced {synced}. {remaining} action(s) still pending.',
      'syncAction': 'this action',
      'syncTimedOut':
          'Sync is taking longer than expected. The app will keep retrying automatically and your pending changes remain saved.',
      'refreshTasks': 'Refresh tasks',
      'refreshUnavailableOffline': 'Refresh is unavailable while offline',
    },
    'am': {
      'workshop': 'ወርክሾፕ',
      'welcomeBack': 'እንኳን ደህና መጡ',
      'signInSubtitle': 'የወርክሾፕ ፈረቃዎን ለማስተዳደር ይግቡ',
      'username': 'የተጠቃሚ ስም',
      'enterUsername': 'የተጠቃሚ ስምዎን ያስገቡ',
      'usernameRequired': 'የተጠቃሚ ስምዎን ያስገቡ',
      'password': 'የይለፍ ቃል',
      'passwordRequired': 'የይለፍ ቃልዎን ያስገቡ',
      'serverSettings': 'የሰርቨር ቅንብሮች',
      'workshopServer': 'የወርክሾፕ ሰርቨር',
      'serverRequired': 'የሰርቨር URL ያስገቡ',
      'continueToWorkshop': 'ወደ ወርክሾፕ ይቀጥሉ',
      'shiftActive': 'ፈረቃ እየሰራ ነው',
      'offDuty': 'ከስራ ውጭ ነዎት',
      'locationRecorded': 'ቦታ ተመዝግቧል · ለስራ ዝግጁ',
      'checkInHint': 'ፈረቃዎን ለመጀመር ይግቡ',
      'checkIn': 'ወደ ስራ ግባ',
      'checkOut': 'ከስራ ውጣ',
      'gettingGps': 'GPS በማግኘት ላይ…',
      'sync': 'አመሳስል',
      'syncing': 'በማመሳሰል ላይ',
      'online': 'መስመር ላይ',
      'offline': 'ከመስመር ውጭ',
      'pendingCount': '{count} በመጠባበቅ ላይ',
      'myTasks': 'የእኔ ተግባራት',
      'availablePool': 'ያሉ ተግባራት',
      'all': 'ሁሉም',
      'assigned': 'የተመደበ',
      'inProgress': 'በሂደት ላይ',
      'completed': 'የተጠናቀቀ',
      'activeTask': 'እየተሰራ ያለ ተግባር',
      'available': 'ዝግጁ',
      'waitingTask': 'ቀጣዩን ተግባር በመጠበቅ ላይ',
      'workTimer': 'የስራ ሰዓት',
      'estimated': 'ግምት',
      'logged': 'የተመዘገበ',
      'takeTask': 'ይህን ተግባር ውሰድ',
      'startWork': 'ስራ ጀምር',
      'stopWorkTimer': 'የስራ ሰዓት አቁም',
      'complete': 'ጨርስ',
      'requestMaterial': 'ዕቃ ጠይቅ',
      'requestOutsource': 'የውጭ አገልግሎት ጠይቅ',
      'noTasks': 'ምንም ተግባር አልተመደበም',
      'retry': 'እንደገና ሞክር',
      'todaySnapshot': 'የዛሬ ማጠቃለያ',
      'navigation': 'መዳረሻ',
      'taskDashboard': 'የተግባር ዳሽቦርድ',
      'taskDashboardSubtitle': 'ፈረቃ፣ ተግባራት እና ማመሳሰል',
      'myRequests': 'የእኔ ጥያቄዎች',
      'requestsSubtitle': 'ዕቃዎች እና የውጭ አገልግሎት',
      'working': 'የስራ ሰዓት',
      'idle': 'የእረፍት ሰዓት',
      'dailyEfficiency': 'የቀን ውጤታማነት',
      'logout': 'ውጣ',
      'language': 'ቋንቋ',
      'english': 'English',
      'amharic': 'አማርኛ',
      'oromo': 'Afaan Oromoo',
      'requestHubSubtitle': 'የወርክሾፕ ድጋፍ ጥያቄዎችን ይከታተሉ',
      'materials': 'ዕቃዎች',
      'outsource': 'የውጭ አገልግሎት',
      'materialRequests': 'የዕቃ ጥያቄዎች',
      'outsourceRequests': 'የውጭ አገልግሎት ጥያቄዎች',
      'noMaterialRequests': 'የዕቃ ጥያቄ የለም',
      'noOutsourceRequests': 'የውጭ አገልግሎት ጥያቄ የለም',
      'newRequestsHint': 'ከተግባር የሚፈጠሩ አዲስ ጥያቄዎች እዚህ ይታያሉ።',
      'unnamedRequest': 'ስም የሌለው ጥያቄ',
      'jobNotSpecified': 'የወርክሾፕ ስራ አልተገለጸም',
      'approved': 'ጸድቋል',
      'rejected': 'ውድቅ ተደርጓል',
      'pending': 'በመጠባበቅ ላይ',
      'submitted': 'ቀርቧል',
      'draft': 'ረቂቅ',
      'refreshRequests': 'ጥያቄዎችን አድስ',
      'requestsLoadError': 'ጥያቄዎች አልታደሱም። ግንኙነትዎን ይፈትሹ።',
      'turnOnLocation': 'ቦታን ያብሩ',
      'locationOffMessage': 'ቦታ ጠፍቷል። ለመግባት ያብሩት። ኢንተርኔት አያስፈልግም።',
      'locationSettings': 'የቦታ ቅንብሮች',
      'locationPermissionNeeded': 'የቦታ ፈቃድ ያስፈልጋል',
      'locationPermissionMessage': 'ከመስመር ውጭም መግባትን ለመመዝገብ የቦታ ፈቃድ ይስጡ።',
      'tryAgain': 'እንደገና ሞክር',
      'allowLocation': 'የቦታ ፈቃድ ስጥ',
      'locationBlockedMessage': 'የቦታ ፈቃድ ታግዷል። ከመተግበሪያ ቅንብሮች ይፍቀዱ።',
      'appSettings': 'የመተግበሪያ ቅንብሮች',
      'cancel': 'ሰርዝ',
      'noNetwork': 'ኔትወርክ የለም። ለውጦችዎ ተቀምጠው ይጠብቃሉ።',
      'alreadyUpToDate': 'ውሂቡ ዘምኗል።',
      'syncFailed': 'ማመሳሰል አልተሳካም። ለውጦችዎ በመሣሪያው ላይ ተቀምጠዋል።',
      'syncPermissionDenied':
          '{action} ማመሳሰል አልተቻለም፤ መለያዎ የስራ መግቢያ/መውጫ መዝገብን ለማሻሻል ፈቃድ የለውም። ድርጊቱ ተቀምጧል። የወርክሾፕ አስተዳዳሪን ያነጋግሩ።',
      'syncServerRejected': 'ሰርቨሩ {action}ን አልተቀበለም። ድርጊቱ በመሣሪያው ላይ ተቀምጧል።',
      'syncSuccess': '{count} ድርጊቶች በተሳካ ሁኔታ ተመሳስለዋል።',
      'syncPartial': '{synced} ተመሳስሏል። {remaining} ድርጊቶች ይጠብቃሉ።',
      'syncAction': 'ይህ ድርጊት',
      'syncTimedOut':
          'ማመሳሰል ከተጠበቀው በላይ ጊዜ ወስዷል። መተግበሪያው በራሱ ይሞክራል፤ ለውጦችዎም ተቀምጠዋል።',
      'refreshTasks': 'ተግባራትን አድስ',
      'refreshUnavailableOffline': 'ከመስመር ውጭ ማደስ አይቻልም',
    },
    'om': {
      'workshop': 'Warshaa Suphaa',
      'welcomeBack': 'Baga nagaan dhuftan',
      'signInSubtitle': 'Hojii warshaa keessan bulchuuf seenaa',
      'username': 'Maqaa fayyadamaa',
      'enterUsername': 'Maqaa fayyadamaa galchi',
      'usernameRequired': 'Maqaa fayyadamaa galchi',
      'password': 'Jecha iccitii',
      'passwordRequired': 'Jecha iccitii galchi',
      'serverSettings': 'Qindaa’ina sarvarii',
      'workshopServer': 'Sarvarii warshaa',
      'serverRequired': 'URL sarvarii galchi',
      'continueToWorkshop': 'Gara warshaatti itti fufi',
      'shiftActive': 'Yeroon hojii jalqabameera',
      'offDuty': 'Hojii ala jirta',
      'locationRecorded': 'Bakki galmaa’eera · hojii qophaa’e',
      'checkInHint': 'Hojii jalqabuuf seeni',
      'checkIn': 'Hojii seeni',
      'checkOut': 'Hojii keessaa ba’i',
      'gettingGps': 'GPS barbaadaa jira…',
      'sync': 'Walsimsiisi',
      'syncing': 'Walsimsiisaa jira',
      'online': 'Toora irra',
      'offline': 'Toora ala',
      'pendingCount': '{count} eegaa jira',
      'myTasks': 'Hojiiwwan koo',
      'availablePool': 'Hojiiwwan jiran',
      'all': 'Hunda',
      'assigned': 'Ramadame',
      'inProgress': 'Hojirra jira',
      'completed': 'Xumurame',
      'activeTask': 'HOJII AMMAA',
      'available': 'QOPHAA’AA',
      'waitingTask': 'Hojii itti aanu eegaa jira',
      'workTimer': 'Sa’aatii hojii',
      'estimated': 'Tilmaama',
      'logged': 'Galmaa’e',
      'takeTask': 'Hojii kana fudhadhu',
      'startWork': 'Hojii jalqabi',
      'stopWorkTimer': 'Sa’aatii hojii dhaabi',
      'complete': 'Xumuri',
      'requestMaterial': 'Meeshaa gaafadhu',
      'requestOutsource': 'Tajaajila alaa gaafadhu',
      'noTasks': 'Hojiin hin ramadamne',
      'retry': 'Irra deebi’i',
      'todaySnapshot': 'CUUNFAA HAR’AA',
      'navigation': 'NAVIGESHINII',
      'taskDashboard': 'Daashboordii hojii',
      'taskDashboardSubtitle': 'Yeroo hojii, hojiiwwan fi walsimsiisa',
      'myRequests': 'Gaaffiiwwan koo',
      'requestsSubtitle': 'Meeshaalee fi tajaajila alaa',
      'working': 'HOJII',
      'idle': 'BOQONNAA',
      'dailyEfficiency': 'Bu’a qabeessummaa guyyaa',
      'logout': 'Ba’i',
      'language': 'Afaan',
      'english': 'English',
      'amharic': 'አማርኛ',
      'oromo': 'Afaan Oromoo',
      'requestHubSubtitle': 'Gaaffii deeggarsa warshaa hordofi',
      'materials': 'Meeshaalee',
      'outsource': 'Tajaajila alaa',
      'materialRequests': 'Gaaffii meeshaa',
      'outsourceRequests': 'Gaaffii tajaajila alaa',
      'noMaterialRequests': 'Gaaffiin meeshaa hin jiru',
      'noOutsourceRequests': 'Gaaffiin tajaajila alaa hin jiru',
      'newRequestsHint': 'Gaaffiiwwan hojii irraa uumaman asitti mul’atu.',
      'unnamedRequest': 'Gaaffii maqaa hin qabne',
      'jobNotSpecified': 'Hojiin warshaa hin ibsamne',
      'approved': 'Mirkanaa’e',
      'rejected': 'Didame',
      'pending': 'Eegaa jira',
      'submitted': 'Dhiyaate',
      'draft': 'Qophii',
      'refreshRequests': 'Gaaffiiwwan haaromsi',
      'requestsLoadError':
          'Gaaffiiwwan haaromsuun hin danda’amne. Quunnamtii ilaali.',
      'turnOnLocation': 'Bakka hojii irra kaa’i',
      'locationOffMessage':
          'Bakki cufameera. Seenuuf bani. Intarneetiin hin barbaachisu.',
      'locationSettings': 'Qindaa’ina bakka',
      'locationPermissionNeeded': 'Hayyamni bakka barbaachisa',
      'locationPermissionMessage':
          'Toora alattis seensa galmeessuuf hayyama bakka kenni.',
      'tryAgain': 'Irra deebi’i',
      'allowLocation': 'Bakka hayyami',
      'locationBlockedMessage':
          'Hayyamni bakka cufameera. Qindaa’ina app keessaa hayyami.',
      'appSettings': 'Qindaa’ina app',
      'cancel': 'Dhiisi',
      'noNetwork': 'Quunnamtiin hin jiru. Jijjiiramni kee nagaan kuufameera.',
      'alreadyUpToDate': 'Daataan yeroo isaa eeggateera.',
      'syncFailed': 'Walsimsiisuun hin milkoofne. Jijjiiramni kee kuufameera.',
      'syncPermissionDenied':
          '{action} walsimsiisuun hin danda’amne; herregni kee galmee hojii jijjiiruuf hayyama hin qabu. Hojiin kun kuufameera. Bulchaa warshaa qunnami.',
      'syncServerRejected':
          'Sarvariin {action} dide. Hojiin kun meeshaa irratti kuufameera.',
      'syncSuccess': 'Hojii {count} milkaa’inaan walsimsiifame.',
      'syncPartial': '{synced} walsimsiifame. {remaining} ammallee eegaa jira.',
      'syncAction': 'hojii kana',
      'syncTimedOut':
          'Walsimsiisuun yeroo dheeraa fudhateera. Appichi ofumaan irra deebi’ee yaala; jijjiiramni kee kuufameera.',
      'refreshTasks': 'Hojiiwwan haaromsi',
      'refreshUnavailableOffline':
          'Toora ala yeroo ta’u haaromsuun hin danda’amu',
    },
  };
}
