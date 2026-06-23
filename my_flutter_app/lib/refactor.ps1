$moves = @{
    'auth_screen.dart' = 'presentation/auth/'
    'login_screen.dart' = 'presentation/auth/'
    'signup_screen.dart' = 'presentation/auth/'
    'welcome_screen.dart' = 'presentation/auth/'
    'biometric_auth_wrapper.dart' = 'presentation/auth/'
    'loan_application_screen.dart' = 'presentation/customer_app/'
    'loan_detail_screen.dart' = 'presentation/customer_app/'
    'loan_selection_screen.dart' = 'presentation/customer_app/'
    'my_loans_screen.dart' = 'presentation/customer_app/'
    'emi_calculator_screen.dart' = 'presentation/customer_app/'
    'refer_friend_form_screen.dart' = 'presentation/partner_app/'
    'referral_dashboard_screen.dart' = 'presentation/partner_app/'
    'banker_form_screen.dart' = 'presentation/b2b_network/'
    'builder_broker_form_screen.dart' = 'presentation/b2b_network/'
    'dsa_form_screen.dart' = 'presentation/b2b_network/'
    'profession_selection_screen.dart' = 'presentation/b2b_network/'
    'status_stories_widget.dart' = 'presentation/b2b_network/'
    'custom_button.dart' = 'presentation/shared/'
    'social_button.dart' = 'presentation/shared/'
    'file_upload_widget.dart' = 'presentation/shared/'
    'root_wrapper.dart' = 'presentation/shared/'
    'user_profile_card.dart' = 'presentation/shared/'
    'home_screen.dart' = 'presentation/shared/'
    'new_home_screen.dart' = 'presentation/shared/'
    'my_profile_screen.dart' = 'presentation/shared/'
    'thank_you_screen.dart' = 'presentation/shared/'
}

Get-ChildItem -Path . -Filter *.dart -Recurse | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file -Raw
    $changed = $false

    foreach ($key in $moves.Keys) {
        $val = $moves[$key]
        if ($content -match $key) {
            $oldContent = $content
            $content = $content -replace "package:my_flutter_app/screens/$key", "package:my_flutter_app/$val$key"
            $content = $content -replace "package:my_flutter_app/widgets/$key", "package:my_flutter_app/$val$key"
            $content = $content -replace "\.\./screens/$key", "package:my_flutter_app/$val$key"
            $content = $content -replace "\.\./widgets/$key", "package:my_flutter_app/$val$key"
            $content = $content -replace "\.\./\.\./screens/$key", "package:my_flutter_app/$val$key"
            $content = $content -replace "\.\./\.\./widgets/$key", "package:my_flutter_app/$val$key"
            
            if ($oldContent -ne $content) {
                $changed = $true
            }
        }
    }

    if ($changed) {
        Set-Content -Path $file -Value $content -Encoding UTF8
        Write-Host "Updated $file"
    }
}
