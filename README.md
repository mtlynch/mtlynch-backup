# mtlynch-backup

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](LICENSE)

## Overview

This is a simple script that I use to back up my personal data.

It is a working example of using my [resticpy](https://github.com/mtlynch/resticpy) library.

The script is meant to run as a regularly scheduled task per day using a tool such as cron or Windows Task Scheduler.

This script performs the following actions:

* Backs up specified paths to one or more cloud backup locations
* Prunes expired data on cloud storage from the backups
* Prints stats about backup repositories

## To use

If you'd like to re-use or adapt this script, it's simple to run yourself.

## Pre-requisites

* restic binary installed
* Python3.7 or above
* python-venv
* Restic backup repositories (already initialized)

### Create a pip virtual environment

```bash
python3 -m venv venv && \
  . venv/bin/activate && \
  pip install --requirement requirements.txt
```

### Create repos file

Create a JSON file that contains information about the cloud storage buckets containing your restic repositories. The script supports S3-style buckets and Backblaze B2 buckets. You can place one or more repos in this file:

```bash
cat > repos.json <<EOF
[
  {
    "accessKeyId": "your-s3-access-key-id",
    "secretAccessKey": "your-s3-secret-access-key",
    "url": "s3:https://your-s3-URL/your-bucket-name"
  },
  {
    "b2AccountId": "your-backblaze-b2-account-id",
    "b2AccountKey": "your-backblaze-b2-account-key",
    "url": "b2:your-backblaze-bucket-url"
  }
]
EOF
```

### Specify backup paths

Create a text file containing the paths you want to back up:

```bash
echo "${HOME}/photos" >> backup-paths.txt
echo "${HOME}/documents" >> backup-paths.txt
```

### Specify exclude paths

Create a file with all the excluded paths from your backup paths:

```bash
echo "${HOME}/photos/resized" >> excludes.txt
echo "${HOME}/documents/junk/reformatted" >> excludes.txt
```

### Create a password file

Create a file containing your repository password:

```bash
printf "mysecretpassword" > "${HOME}/restic-pass.txt"
```

* Note: This script assumes that all repositories share a single password.

### Launch a backup

With everything in place, run the backup script:

```bash
# Replace with number of daily snapshots you want to keep.
DAILY_SNAPSHOTS_TO_KEEP=60

./backup.py \
  --repos-file repos.json \
  --backup-paths-file backup-paths.txt \
  --exclude-file excludes.txt \
  --password-file "${HOME}/restic-pass.txt" \
  --keep-daily "${DAILY_SNAPSHOTS_TO_KEEP}"
```

You can use cron or other job schedulers to run this script regularly.
