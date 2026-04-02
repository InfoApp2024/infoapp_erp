import yaml
import json
import os

def generate_version():
    pubspec_path = 'pubspec.yaml'
    version_json_path = 'web/version.json'
    
    if not os.path.exists(pubspec_path):
        print(f"Error: {pubspec_path} not found.")
        return

    with open(pubspec_path, 'r') as file:
        try:
            pubspec = yaml.safe_load(file)
            version = pubspec.get('version', '1.0.0+1')
            
            # version.json format: {"version": "1.0.0+1"}
            version_data = {
                "version": version
            }
            
            # Ensure web directory exists
            os.makedirs('web', exist_ok=True)
            
            with open(version_json_path, 'w') as json_file:
                json.dump(version_data, json_file, indent=4)
                
            print(f"Successfully generated {version_json_path} with version {version}")
        except Exception as e:
            print(f"Error processing pubspec.yaml: {e}")

if __name__ == "__main__":
    generate_version()
