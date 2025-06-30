import os

# Extensions we want to include
ALLOWED_EXTENSIONS = {
    '.sh', '.txt', '.py', '.json', '.yaml', '.yml',
    '.log', '.sql', '.md', '.js',
    '.bak', '.backup', '.tmp', '.tmp2', '.ipynb'
}


def has_allowed_extension(filename):
    return any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS)


def is_text_file(file_path):
    """Check if a file is readable text-based."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            f.read(1024)
        return True
    except:
        return False


def backup_project(root_dir, output_file):
    with open(output_file, 'w', encoding='utf-8') as backup:
        for dirpath, _, filenames in os.walk(root_dir):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                rel_path = os.path.relpath(file_path, root_dir)

                # Skip junk files or disallowed extensions
                if not has_allowed_extension(filename):
                    continue
                if '__pycache__' in rel_path or '.DS_Store' in rel_path or filename.endswith('.pyc'):
                    continue
                if not is_text_file(file_path):
                    continue

                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                except Exception as e:
                    content = f"--- Error reading file: {e} ---"

                # Write to backup file
                backup.write(f"\n{'='*100}\n")
                backup.write(f"File: {rel_path}\n")
                backup.write(f"{'-'*100}\n")
                backup.write(content + '\n')


if __name__ == "__main__":
    root_dir = os.getcwd()  # Run in the root directory of your project
    output_file = "backup.txt"
    backup_project(root_dir, output_file)
    print(f"✅ Backup complete. Output saved to: {output_file}")
