import re
import json
import sys

def parse_firebase_options(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return {}

    platforms = ['web', 'android', 'ios']
    result = {}

    for platform in platforms:
        # Match static const FirebaseOptions <platform> = FirebaseOptions(...)
        pattern = rf'static const FirebaseOptions {platform} = FirebaseOptions\((.*?)\);'
        match = re.search(pattern, content, re.DOTALL)
        if match:
            options_str = match.group(1)
            options = {}
            for line in options_str.split('\n'):
                line = line.strip()
                if not line or line.startswith('//'): continue
                if ':' in line:
                    key, val = line.split(':', 1)
                    key = key.strip()
                    val = val.strip().strip("',")
                    options[key] = val
            result[platform] = json.dumps(options)
    
    return result

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python extract_firebase_json.py <APP_PREFIX> <PATH_TO_FIREBASE_OPTIONS_DART>")
        sys.exit(1)
        
    app_name = sys.argv[1] # e.g., CRM or DSA
    filepath = sys.argv[2]
    configs = parse_firebase_options(filepath)
    
    with open('firebase_secrets.txt', 'a', encoding='utf-8') as out:
        out.write(f"\n=== {app_name} FIREBASE SECRETS ===\n")
        if 'android' in configs:
            out.write(f"{app_name}_FIREBASE_ANDROID='{configs['android']}'\n")
        if 'ios' in configs:
            out.write(f"{app_name}_FIREBASE_IOS='{configs['ios']}'\n")
        if 'web' in configs:
            out.write(f"{app_name}_FIREBASE_WEB='{configs['web']}'\n")
        print(f"Extracted secrets for {app_name}")
