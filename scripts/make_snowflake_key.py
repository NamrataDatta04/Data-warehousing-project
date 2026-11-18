#!/usr/bin/env python3
"""Create the key pair a Snowflake service user signs in with.

The private key is saved in a .snowflake folder in your home folder, outside this
repository, and is never printed. The public key is printed so you can paste it into
the matching Snowflake setup script. Running the script again reuses the existing key.

  python scripts/make_snowflake_key.py                               # dbt_svc, for dbt
  python scripts/make_snowflake_key.py --user powerbi_svc --encrypt  # for Power BI

Power BI's Snowflake connector only accepts a passphrase-protected private key,
so --encrypt asks for a passphrase and stores the key encrypted with it.
"""
from __future__ import annotations

import argparse
import getpass
import sys
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

SETUP_SCRIPT = {"dbt_svc": "snowflake/01_setup.sql", "powerbi_svc": "snowflake/03_powerbi_access.sql"}


def ask_passphrase(confirm: bool) -> bytes:
    passphrase = getpass.getpass("Passphrase for the private key (typing is hidden): ")
    if len(passphrase) < 8:
        sys.exit("Use a passphrase of at least 8 characters.")
    if confirm and getpass.getpass("Type it again: ") != passphrase:
        sys.exit("The two passphrases did not match. Nothing was saved.")
    return passphrase.encode()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--user", default="dbt_svc", choices=sorted(SETUP_SCRIPT), help="Snowflake user the key is for")
    ap.add_argument("--encrypt", action="store_true", help="protect the private key with a passphrase")
    args = ap.parse_args()
    key_path = Path.home() / ".snowflake" / f"{args.user}_key.p8"

    if key_path.exists():
        data = key_path.read_bytes()
        password = ask_passphrase(confirm=False) if b"ENCRYPTED" in data else None
        try:
            private_key = serialization.load_pem_private_key(data, password=password)
        except (TypeError, ValueError):
            sys.exit(f"Could not open {key_path}. Check the passphrase.")
        print(f"Using the existing private key at {key_path}\n")
    else:
        key_path.parent.mkdir(parents=True, exist_ok=True)
        encryption = (serialization.BestAvailableEncryption(ask_passphrase(confirm=True))
                      if args.encrypt else serialization.NoEncryption())
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        key_path.write_bytes(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=encryption,
        ))
        try:
            key_path.chmod(0o600)
        except OSError:
            pass
        print(f"Saved a new private key to {key_path}  (keep it private; never commit it)\n")

    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    public_key = "".join(line for line in public_pem.splitlines() if "PUBLIC KEY" not in line)

    print(f"Public key - paste this in place of <public-key> in {SETUP_SCRIPT[args.user]}:\n")
    print(public_key)
    if args.user == "dbt_svc":
        print("\nThen, in PowerShell, tell dbt where the private key is:\n")
        print(f'$env:SNOWFLAKE_PRIVATE_KEY_PATH="{key_path}"')
    else:
        print(f"\nPower BI needs the full text of {key_path} (open it in Notepad) and your passphrase.")


if __name__ == "__main__":
    main()
