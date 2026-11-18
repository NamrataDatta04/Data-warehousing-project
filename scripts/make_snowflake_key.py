#!/usr/bin/env python3
"""Create the key pair that the dbt_svc Snowflake user signs in with.

The private key is saved in a .snowflake folder in your home folder, outside this
repository, and is never printed. The public key is printed so you can paste it into
snowflake/01_setup.sql. Running the script again reuses the existing key.

Usage:  python scripts/make_snowflake_key.py
"""
from __future__ import annotations

from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

KEY_PATH = Path.home() / ".snowflake" / "dbt_svc_key.p8"


def main() -> None:
    if KEY_PATH.exists():
        private_key = serialization.load_pem_private_key(KEY_PATH.read_bytes(), password=None)
        print(f"Using the existing private key at {KEY_PATH}\n")
    else:
        KEY_PATH.parent.mkdir(parents=True, exist_ok=True)
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        KEY_PATH.write_bytes(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ))
        try:
            KEY_PATH.chmod(0o600)
        except OSError:
            pass
        print(f"Saved a new private key to {KEY_PATH}  (keep it private; never commit it)\n")

    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    public_key = "".join(line for line in public_pem.splitlines() if "PUBLIC KEY" not in line)

    print("Public key - paste this in place of <public-key> in snowflake/01_setup.sql:\n")
    print(public_key)
    print("\nThen, in PowerShell, tell dbt where the private key is:\n")
    print(f'$env:SNOWFLAKE_PRIVATE_KEY_PATH="{KEY_PATH}"')


if __name__ == "__main__":
    main()
