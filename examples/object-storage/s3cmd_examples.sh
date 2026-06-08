#!/bin/bash

# Do not run this file as-is during a workshop. Copy the commands you need and
# replace placeholders with your own bucket names and credentials.

s3cmd --configure

# CloudCIX Object Storage configuration values:
# Default Region: boole-zonegroup
# S3 Endpoint: s3-boole.cloudcix.com
# DNS-style: no

BUCKET="s3://replace-with-your-unique-bucket-name"

s3cmd mb "$BUCKET"
echo "Hello from Boole HPC object storage" > file.txt
s3cmd put file.txt "$BUCKET"
s3cmd ls "$BUCKET"
s3cmd get "$BUCKET/file.txt" downloaded-file.txt
