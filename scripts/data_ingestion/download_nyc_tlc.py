#!/usr/bin/env python3
"""
Download NYC TLC Yellow Taxi trip data and upload to MinIO.

Usage:
    python download_nyc_tlc.py --start-month 2023-01 --end-month 2024-12 \
        --endpoint http://localhost:9000 --bucket nyc-taxi --path raw/

For running inside k8s cluster:
    python download_nyc_tlc.py --start-month 2023-01 --end-month 2024-12 \
        --endpoint http://minio.spark-infra.svc.cluster.local:9000
"""

import argparse
import os
import sys
from datetime import datetime
from dateutil.relativedelta import relativedelta
import requests
import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from io import BytesIO
import pyarrow.parquet as pq
import pyarrow as pa


def get_month_range(start_month: str, end_month: str) -> list:
    """Generate list of months in YYYY-MM format."""
    start = datetime.strptime(start_month, "%Y-%m")
    end = datetime.strptime(end_month, "%Y-%m")
    months = []
    current = start
    while current <= end:
        months.append(current.strftime("%Y-%m"))
        current += relativedelta(months=1)
    return months


def download_tlc_parquet(month: str, verbose: bool = True) -> bytes:
    """Download TLC parquet file for a given month."""
    url = f"https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{month}.parquet"

    if verbose:
        print(f"  Downloading {url}...")

    response = requests.get(url, timeout=300)
    response.raise_for_status()

    if verbose:
        print(f"  Downloaded {len(response.content):,} bytes")

    return response.content


def create_minio_client(endpoint: str, access_key: str, secret_key: str):
    """Create MinIO S3 client."""
    return boto3.client(
        's3',
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version='s3v4'),
        region_name='us-east-1'
    )


def ensure_bucket(s3_client, bucket_name: str):
    """Create bucket if it doesn't exist."""
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"Bucket '{bucket_name}' exists")
    except ClientError:
        print(f"Creating bucket '{bucket_name}'...")
        s3_client.create_bucket(Bucket=bucket_name)
        print(f"Bucket '{bucket_name}' created")


def upload_to_minio(s3_client, bucket: str, key: str, data: bytes):
    """Upload data to MinIO."""
    s3_client.put_object(Bucket=bucket, Key=key, Body=data)
    print(f"  Uploaded to s3a://{bucket}/{key}")


def validate_parquet(data: bytes) -> dict:
    """Validate parquet file and return stats."""
    table = pq.read_table(BytesIO(data))
    return {
        'rows': table.num_rows,
        'columns': len(table.column_names),
        'column_names': table.column_names,
    }


def main():
    parser = argparse.ArgumentParser(description='Download NYC TLC data to MinIO')
    parser.add_argument('--start-month', required=True, help='Start month (YYYY-MM)')
    parser.add_argument('--end-month', required=True, help='End month (YYYY-MM)')
    parser.add_argument('--endpoint', default='http://localhost:9000', help='MinIO endpoint')
    parser.add_argument('--access-key', default='minioadmin', help='MinIO access key')
    parser.add_argument('--secret-key', default='minioadmin', help='MinIO secret key')
    parser.add_argument('--bucket', default='nyc-taxi', help='MinIO bucket name')
    parser.add_argument('--path', default='raw/', help='Path prefix in bucket')
    parser.add_argument('--dry-run', action='store_true', help='Download but do not upload')
    parser.add_argument('--limit', type=int, help='Limit number of months (for testing)')
    parser.add_argument('--sample', action='store_true', help='Sample data (10% of rows)')

    args = parser.parse_args()

    print(f"NYC TLC Data Ingestion")
    print(f"======================")
    print(f"Source: NYC TLC Yellow Taxi")
    print(f"Period: {args.start_month} to {args.end_month}")
    print(f"Target: s3a://{args.bucket}/{args.path}")
    print()

    # Get months
    months = get_month_range(args.start_month, args.end_month)
    if args.limit:
        months = months[:args.limit]

    print(f"Months to process: {len(months)}")
    print()

    # Create MinIO client
    if not args.dry_run:
        s3_client = create_minio_client(args.endpoint, args.access_key, args.secret_key)
        ensure_bucket(s3_client, args.bucket)
    else:
        print("DRY RUN - not uploading to MinIO")
        s3_client = None

    # Process each month
    total_rows = 0
    for i, month in enumerate(months, 1):
        print(f"[{i}/{len(months)}] Processing {month}...")

        try:
            # Download
            data = download_tlc_parquet(month)

            # Validate
            stats = validate_parquet(data)
            print(f"  Validated: {stats['rows']:,} rows, {stats['columns']} columns")
            total_rows += stats['rows']

            # Sample if requested
            if args.sample:
                table = pq.read_table(BytesIO(data))
                sample_frac = 0.1
                sampled = table.slice(0, int(len(table) * sample_frac))
                buf = BytesIO()
                pq.write_table(sampled, buf)
                data = buf.getvalue()
                print(f"  Sampled to {len(sampled):,} rows")

            # Upload
            key = f"{args.path}yellow_tripdata_{month}.parquet"
            if s3_client:
                upload_to_minio(s3_client, args.bucket, key, data)

            print(f"  Done!")

        except Exception as e:
            print(f"  ERROR: {e}")
            continue

        print()

    print(f"Summary: {total_rows:,} total rows processed")

    return 0


if __name__ == '__main__':
    sys.exit(main())
