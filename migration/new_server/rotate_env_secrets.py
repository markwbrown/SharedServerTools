#!/usr/bin/env python3
import argparse
import secrets
from pathlib import Path
import shutil
import sys

def mask_value(value: str, max_len: int = 32) -> str:
    """Return a masked preview of the current value."""
    if value == "":
        return "(empty)"
    if len(value) <= 6:
        return "*" * len(value)
    shortened = value
    if len(value) > max_len:
        shortened = value[:max_len] + "…"
    return f"{shortened[:3]}***{shortened[-3:]}"

def generate_secret() -> str:
    """Generate a new secure random secret."""
    # URL-safe, 32-ish characters, good for most env secrets.
    return secrets.token_urlsafe(32)

def process_env_file(env_path: Path) -> None:
    print(f"\n=== Processing .env file: {env_path} ===")

    original = env_path.read_text(encoding="utf-8").splitlines(keepends=True)
    new_lines = []
    modified = False
    skip_this_file = False

    for line in original:
        # Preserve raw line by default
        raw = line.rstrip("\n")
        stripped = raw.strip()

        # Comments / blank lines: keep as-is
        if stripped == "" or stripped.startswith("#"):
            new_lines.append(line)
            continue

        # Very simple KEY=VALUE parsing (no export support here on purpose)
        if "=" not in raw:
            # Not a standard env line, keep as-is
            new_lines.append(line)
            continue

        key, value = raw.split("=", 1)
        key = key.strip()
        # Don't strip value: we want to preserve spaces if user keeps it
        current_value = value

        print(f"\nKey: {key}")
        print(f"Current value: {mask_value(current_value)}")

        while True:
            choice = input("(k)eep / (r)ewrite / (s)kip file / (q)uit [k]: ").strip().lower() or "k"
            if choice not in {"k", "r", "s", "q"}:
                print("Please enter k (keep), r (rewrite), s (skip file), or q (quit).")
                continue
            break

        if choice == "q":
            print("[-] Quitting at user request.")
            # Write nothing, leave file untouched
            sys.exit(0)

        if choice == "s":
            print("[*] Skipping this file, leaving it unchanged.")
            skip_this_file = True
            break

        if choice == "k":
            # Keep line exactly as-is
            new_lines.append(line)
            continue

        if choice == "r":
            new_secret = generate_secret()
            print(f"[+] Generated new value for {key}: {mask_value(new_secret)}")
            new_line = f"{key}={new_secret}\n"
            new_lines.append(new_line)
            modified = True

    if skip_this_file or not modified:
        # No changes → nothing to write
        return

    # Backup original file
    backup_path = env_path.with_suffix(env_path.suffix + ".bak")
    print(f"[*] Creating backup: {backup_path}")
    shutil.copy2(env_path, backup_path)

    # Write updated file
    print(f"[+] Writing updated .env: {env_path}")
    env_path.write_text("".join(new_lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(
        description="Interactively rotate secrets in .env files under a base directory."
    )
    parser.add_argument(
        "base_dir",
        help="Base directory to search for .env files (e.g. /root/migrate/home-git-configs)",
    )
    args = parser.parse_args()

    base = Path(args.base_dir).resolve()
    if not base.is_dir():
        print(f"[-] {base} is not a directory.")
        sys.exit(1)

    env_files = sorted(base.rglob(".env"))
    if not env_files:
        print(f"[!] No .env files found under {base}")
        sys.exit(0)

    print(f"[*] Found {len(env_files)} .env files under {base}.")

    for env_path in env_files:
        process_env_file(env_path)

    print("\n[+] Done. Any modified .env files have a .env.bak backup next to them.")

if __name__ == "__main__":
    main()
