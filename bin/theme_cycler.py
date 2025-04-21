import subprocess
import os

def set_theme(theme: str, is_light: bool = False) -> None:
    cmd = ['wal']
    if is_light:
        cmd.append('-l')
    cmd.extend(['--theme', theme])
    subprocess.run(cmd)

def main():
    themes_file = 'themes.txt'
    if not os.path.exists(themes_file):
        print(f"Error: File {themes_file} does not exist.")
        return

    with open(themes_file, 'r') as f:
        lines = f.readlines()
    
    # Remove leading "- " from each line and strip whitespace
    themes = [line[2:].strip() for line in lines]
    current_index = 0

    while True:
        print(f"Current Theme: {themes[current_index]}")
        choice = input("Enter 'n' for next, 'p' for previous, 'q' to quit: ").strip().lower()

        if choice == 'n':
            current_index = (current_index + 1) % len(themes)
            set_theme(themes[current_index])
        elif choice == 'p':
            current_index = (current_index - 1) % len(themes)
            set_theme(themes[current_index])
        elif choice == 'q':
            break
        else:
            print("Invalid option.")

if __name__ == '__main__':
    main()

