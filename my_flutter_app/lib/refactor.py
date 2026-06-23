import os
import re

moves = {
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
}

for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            changed = False
            new_lines = []
            for line in lines:
                if line.startswith('import '):
                    for fname, folder in moves.items():
                        if fname in line:
                            match = re.search(r"['\"](.*?)['\"]", line)
                            if match:
                                old_path = match.group(1)
                                if old_path.startswith('package:my_flutter_app/') or old_path.startswith('.') or old_path.startswith('..'):
                                    new_path = f"package:my_flutter_app/{folder}{fname}"
                                    line = line.replace(old_path, new_path)
                                    changed = True
                            break
                new_lines.append(line)
            
            if changed:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
                print(f"Updated {file_path}")

try:
    os.rmdir('screens')
except Exception as e:
    pass

try:
    os.rmdir('widgets')
except Exception as e:
    pass
