import 'dart:io';

void main() {
  final moves = {
    'auth_screen.dart': 'presentation/auth/',
    'login_screen.dart': 'presentation/auth/',
    'signup_screen.dart': 'presentation/auth/',
    'welcome_screen.dart': 'presentation/auth/',
    'biometric_auth_wrapper.dart': 'presentation/auth/',
    'loan_application_screen.dart': 'presentation/customer_app/',
    'loan_detail_screen.dart': 'presentation/customer_app/',
    'loan_selection_screen.dart': 'presentation/customer_app/',
    'my_loans_screen.dart': 'presentation/customer_app/',
    'emi_calculator_screen.dart': 'presentation/customer_app/',
    'refer_friend_form_screen.dart': 'presentation/partner_app/',
    'referral_dashboard_screen.dart': 'presentation/partner_app/',
    'banker_form_screen.dart': 'presentation/b2b_network/',
    'builder_broker_form_screen.dart': 'presentation/b2b_network/',
    'dsa_form_screen.dart': 'presentation/b2b_network/',
    'profession_selection_screen.dart': 'presentation/b2b_network/',
    'status_stories_widget.dart': 'presentation/b2b_network/',
    'custom_button.dart': 'presentation/shared/',
    'social_button.dart': 'presentation/shared/',
    'file_upload_widget.dart': 'presentation/shared/',
    'root_wrapper.dart': 'presentation/shared/',
    'user_profile_card.dart': 'presentation/shared/',
    'home_screen.dart': 'presentation/shared/',
    'new_home_screen.dart': 'presentation/shared/',
    'my_profile_screen.dart': 'presentation/shared/',
    'thank_you_screen.dart': 'presentation/shared/',
  };

  final dir = Directory('.');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    for (final entry in moves.entries) {
      final key = entry.key;
      final val = entry.value;

      final oldS1 = 'package:my_flutter_app/screens/$key';
      final oldS2 = 'package:my_flutter_app/widgets/$key';
      final oldS3 = '../screens/$key';
      final oldS4 = '../widgets/$key';
      final oldS5 = '../../screens/$key';
      final oldS6 = '../../widgets/$key';
      
      final newPath = 'package:my_flutter_app/$val$key';

      if (content.contains(oldS1)) { content = content.replaceAll(oldS1, newPath); changed = true; }
      if (content.contains(oldS2)) { content = content.replaceAll(oldS2, newPath); changed = true; }
      if (content.contains(oldS3)) { content = content.replaceAll(oldS3, newPath); changed = true; }
      if (content.contains(oldS4)) { content = content.replaceAll(oldS4, newPath); changed = true; }
      if (content.contains(oldS5)) { content = content.replaceAll(oldS5, newPath); changed = true; }
      if (content.contains(oldS6)) { content = content.replaceAll(oldS6, newPath); changed = true; }
      
      final oldS7 = "'$key'";
      if (content.contains("import $oldS7")) {
        content = content.replaceAll("import $oldS7", "import '$newPath'");
        changed = true;
      }
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
