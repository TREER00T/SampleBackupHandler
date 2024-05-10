# Backup Mechanism Implementation Guide

This guide outlines the steps to implement a backup mechanism utilizing AWS S3 storage, cron jobs, and shell scripts.

## Step 1: Install AWS SDK

```shell
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install unzip
unzip awscliv2.zip
sudo ./aws/install
```

## Step 2: AWS Configuration

```shell
sudo aws configure
```

Configure your access key ID, secret access key, and region. skip the last option if unsure.

## Step 3: Install Cron

```shell
sudo apt-get install cron
```

## Step 4: Launch Scripts

1. Create a new folder: `mkdir /home/backup`
2. Download scripts and copy the zip file to `/home/backup`.
3. Create a .env file in `/home/backup` and set the following environment variables:
4. Grant execute access to scripts: `sudo chmod +x /home/backup/*.sh`

| KEY                  | Type   | Required | Description                                                |
|----------------------|--------|----------|------------------------------------------------------------|
| S3_BUCKET            | String | true     | S3 bucket name                                             |
| ENDPOINT_URL         | String | true     | S3 endpoint url                                            |
| STORAGE_PERIOD       | Number | true     | Duration of file retention                                 |
| SCRIPT_PATH          | String | true     | Address of root scripts of the project                     |
| TARGET_PATH          | String | true     | The address of the backup path                             |
| ARCHIVE_MONGODB_PATH | String | false    | The address of the backup path inside the docker container |
| MONGODB_USERNAME     | String | false    | MongoDB username                                           |
| MONGODB_PASSWORD     | String | false    | MongoDB password                                           |
| MONGODB_PORT         | Number | false    | MongoDB port                                               |
| MONGODB_DOCKER_NAME  | String | false    | Choosing custom MongoDB docker container name              |

Note 📒: The mongo values are required when the mongo container exists

### Example

```text
S3_BUCKET=bucket_test
ENDPOINT_URL=https://domain.com
STORAGE_PERIOD=30
SCRIPT_PATH=/home/backup
TARGET_PATH=/home/app
ARCHIVE_MONGODB_PATH=/data/db/test.dump
MONGODB_USERNAME=MONGODB_USERNAME
MONGODB_PASSWORD=MONGODB_PASSWORD
MONGODB_PORT=MONGODB_PORT
```

## Step 5: Cron Job Configuration

```shell
sudo crontab -e
```

Choose your preferred editor and add the following commands:

```shell
0 1 * * * /home/backup/make-backup.sh --path=/home/backup >> /home/backup/make-backup-error.log 2>&1
0 1 * * * /home/backup/delete-old-file.sh --path=/home/backup >> /home/backup/delete-old-file-error.log 2>&1
```

## Exclude file or folder

To exclude, create a file named `exclude.txt` in the main path of the scripts and then add your files and folders.

### Example

**exclude.txt**

```txt
./out
./*.env
```

## Custom mongodb docker name

To enable this feature, the all thing that to do is set docker name on env

### Example

```shell
MONGODB_DOCKER_NAME=mongodb-1
```