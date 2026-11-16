#!/usr/bin/env python3
"""Upload the generated source extracts to an Azure Blob Storage container.

Run scripts/generate_source_data.py first. The connection string is read from the
AZURE_STORAGE_CONNECTION_STRING environment variable so that it is never written to a file.

Usage:  python scripts/upload_to_azure.py [--source data/raw] [--container raw]
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from azure.storage.blob import BlobServiceClient


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--source", default="data/raw", help="local folder to upload")
    ap.add_argument("--container", default="raw", help="existing blob container to upload into")
    args = ap.parse_args()

    connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    if not connection_string:
        sys.exit("Set the AZURE_STORAGE_CONNECTION_STRING environment variable first.")
    source = Path(args.source)
    files = sorted(p for p in source.rglob("*.csv"))
    if not files:
        sys.exit(f"No CSV files found in {source}. Run scripts/generate_source_data.py first.")

    container = BlobServiceClient.from_connection_string(connection_string).get_container_client(args.container)
    total_bytes = 0
    for number, path in enumerate(files, start=1):
        blob_name = path.relative_to(source).as_posix()   # e.g. pos_a/AKL01/sales_2025Q1.csv
        with path.open("rb") as handle:
            container.upload_blob(name=blob_name, data=handle, overwrite=True)
        total_bytes += path.stat().st_size
        print(f"[{number:>3}/{len(files)}] {blob_name}")
    print(f"Uploaded {len(files)} files ({total_bytes / 1e6:.1f} MB) to container '{args.container}'.")


if __name__ == "__main__":
    main()
