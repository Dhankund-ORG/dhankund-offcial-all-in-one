import subprocess
import os

def set_secrets():
    filepath = 'firebase_secrets.txt'
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
        
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('='):
                continue
            if '=' in line:
                key, val = line.split('=', 1)
                # Remove surrounding quotes
                if (val.startswith("'") and val.endswith("'")) or (val.startswith('"') and val.endswith('"')):
                    val = val[1:-1]
                
                print(f"Setting secret: {key} ...")
                # Use subprocess to set the secret using gh cli
                try:
                    subprocess.run(
                        ['gh', 'secret', 'set', key, '-b', val],
                        check=True,
                        text=True
                    )
                    print(f"Successfully set {key}")
                except subprocess.CalledProcessError as e:
                    print(f"Failed to set {key}: {e}")

if __name__ == "__main__":
    set_secrets()
