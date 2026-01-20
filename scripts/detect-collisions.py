import os
import re
import sys

BASE_DIR = os.path.expanduser("~/.local/share/chezmoi/.chezmoitemplates")
ALIASES_DIR = os.path.join(BASE_DIR, "aliases")
FUNCTIONS_DIR = os.path.join(BASE_DIR, "functions")

definitions = {}
collisions = []

def scan_file(filepath, kind):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # Regex for aliases: alias name='...' or alias name="..."
    # We focus on the name.
    if kind == "alias":
        # simple regex, might miss multi-line or complex cases but good enough for 99%
        matches = re.findall(r"^\s*alias\s+([a-zA-Z0-9_-]+)=['\"]", content, re.MULTILINE)
        for name in matches:
            record_definition(name, "alias", filepath)

    # Regex for functions: name() { or function name {
    if kind == "function":
        matches = re.findall(r"^([a-zA-Z0-9_-]+)\s*\(\)\s*\{", content, re.MULTILINE)
        for name in matches:
            record_definition(name, "function", filepath)
            
        matches_kwd = re.findall(r"^function\s+([a-zA-Z0-9_-]+)", content, re.MULTILINE)
        for name in matches_kwd:
             record_definition(name, "function", filepath)

def record_definition(name, kind, filepath):
    rel_path = os.path.relpath(filepath, BASE_DIR)
    
    if name in definitions:
        prev_def = definitions[name]
        # Ignore if it's the exact same file (unlikely unless file parsed twice)
        if prev_def['filepath'] != rel_path:
             collisions.append({
                 "name": name,
                 "kind": kind,
                 "conflict_with_kind": prev_def['kind'],
                 "file1": prev_def['filepath'],
                 "file2": rel_path
             })
    else:
        definitions[name] = {
            "kind": kind,
            "filepath": rel_path
        }

def main():
    print(f"Scanning for collisions within {BASE_DIR}...")
    
    # Scan Aliases
    for root, dirs, files in os.walk(ALIASES_DIR):
        for file in files:
            if file.endswith(".sh"):
                scan_file(os.path.join(root, file), "alias")

    # Scan Functions
    for root, dirs, files in os.walk(FUNCTIONS_DIR):
        for file in files:
            if file.endswith(".sh"):
                scan_file(os.path.join(root, file), "function")

    if collisions:
        print(f"\n❌ Found {len(collisions)} collisions/duplicates:")
        for c in collisions:
            print(f"  - '{c['name']}' ({c['kind']}) in {c['file2']} conflicts with ({c['conflict_with_kind']}) in {c['file1']}")
        sys.exit(1)
    else:
        print("\n✅ No collisions found between aliases and functions.")
        sys.exit(0)

if __name__ == "__main__":
    main()
