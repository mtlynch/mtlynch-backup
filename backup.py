#!/usr/bin/env python3

import argparse
import json
import locale
import logging
import os
import os.path

import restic

logger = logging.getLogger(__name__)


def configure_logging():
    root_logger = logging.getLogger()
    handler = logging.StreamHandler()
    formatter = logging.Formatter(
        '%(asctime)s %(name)-15s %(levelname)-4s %(message)s',
        '%Y-%m-%d %H:%M:%S')
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.INFO)


def process_repos(repos, backup_paths, exclude_patterns, exclude_files,
                  keep_daily):
    for repo in repos:
        process_repo(repo, backup_paths, exclude_patterns, exclude_files,
                     keep_daily)


def process_repo(repo, backup_paths, exclude_patterns, exclude_files,
                 keep_daily):
    try:
        back_up(repo, backup_paths, exclude_patterns, exclude_files)
        prune_backups(repo, keep_daily)
        check_stats(repo)
    except Exception as e:
        logger.error('Processing repo failed: %s', str(e))


def print_version():
    version_info = restic.version()
    logger.info('Backing up with restic version %s (%s/%s/go%s)',
                version_info['restic_version'], version_info['architecture'],
                version_info['platform_version'], version_info['go_version'])


def format_json(obj):
    return json.dumps(obj, sort_keys=True, indent=2)


def set_repo_environment_variables(repo):
    if 'b2AccountId' in repo:
        os.environ['B2_ACCOUNT_ID'] = repo['b2AccountId']
        os.environ['B2_ACCOUNT_KEY'] = repo['b2AccountKey']
    else:
        os.environ['AWS_ACCESS_KEY_ID'] = repo['accessKeyId']
        os.environ['AWS_SECRET_ACCESS_KEY'] = repo['secretAccessKey']
    restic.repository = repo['url']


def read_backup_paths(backup_paths_path):
    with open(backup_paths_path) as backup_paths_file:
        return [p.strip() for p in backup_paths_file.readlines() if p.strip()]


def read_repos(repos_path):
    with open(repos_path) as repos_file:
        return json.load(repos_file)


def back_up(repo, backup_paths, exclude_patterns, exclude_files):
    logger.info('Backing up to %s...', repo['url'])
    set_repo_environment_variables(repo)
    restic.unlock()
    result = restic.backup(paths=backup_paths,
                           exclude_patterns=exclude_patterns,
                           exclude_files=exclude_files)
    log_backup_result(result)


def prune_backups(repo, keep_daily):
    logger.info('Pruning repo %s...', repo['url'])
    set_repo_environment_variables(repo)
    restic.unlock()
    restic.forget(prune=True, keep_daily=keep_daily)
    logger.info('Prune complete')


def check_stats(repo):
    logger.info('Retrieving stats for repo %s...', repo['url'])
    set_repo_environment_variables(repo)
    restic.unlock()
    log_stats_result(restic.stats(mode='files-by-contents'))


def human_size(bytes, units=[' bytes', ' KB', ' MB', ' GB', ' TB']):
    return str(bytes) + units[0] if bytes < 1024 else human_size(
        bytes >> 10, units[1:])


def format_integer(integer):
    return locale.format_string('%d', integer, grouping=True)


def human_time(value, units=['seconds', 'minutes', 'hours']):
    return ('%.1f ' % value) + units[0] if value < 60 else human_time(
        value / 60.0, units[1:])


def log_backup_result(backup_result):
    logger.info('%s added', human_size(backup_result['data_added']))
    logger.info('%s files changed',
                format_integer(backup_result['files_changed']))
    logger.info('%s new files', format_integer(backup_result['files_new']))
    logger.info('%s (%s) files processed',
                format_integer(backup_result['total_files_processed']),
                human_size(backup_result['total_bytes_processed']))
    logger.info('Duration: %s', human_time(backup_result['total_duration']))


def log_stats_result(stats_result):
    logger.info('%s files (%s)',
                format_integer(stats_result['total_file_count']),
                human_size(stats_result['total_size']))


def clear_environment_variables():
    ENVIRONMENT_VARS = [
        'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'B2_ACCOUNT_ID',
        'B2_ACCOUNT_KEY'
    ]
    for ENVIRONMENT_VAR in ENVIRONMENT_VARS:
        if ENVIRONMENT_VAR in os.environ:
            del os.environ[ENVIRONMENT_VAR]


def main(args):
    configure_logging()
    if args.restic_path:
        restic.binary_path = args.restic_path
    restic.password_file = args.password_file
    print_version()
    try:
        backup_paths = read_backup_paths(args.backup_paths_file)
        repos = read_repos(args.repos_file)
        process_repos(repos, backup_paths, args.exclude, args.exclude_file,
                    args.keep_daily)
        logger.info('Backups complete!')
    finally:
        clear_environment_variables()
        logger.info('Cleared environment variables')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='Restic Backup Runner',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--restic-path',
                        help='path to restic binary (if not in PATH)')
    parser.add_argument('--password-file',
                        required=True,
                        help="text file containing repository password")
    parser.add_argument('--backup-paths-file',
                        required=True,
                        help='text file containing backup paths')
    parser.add_argument('--repos-file',
                        required=True,
                        help='JSON file containing a list of backup repos')
    parser.add_argument('--exclude-file', action='append', default=[])
    parser.add_argument('--exclude', action='append', default=[])
    parser.add_argument('--keep-daily', type=int)
    main(parser.parse_args())


def configure_global_settings():
    restic.binary_path = 'c:\\restic\\restic.exe'
    restic.password_file = 'C:\\restic\\pass.txt'
