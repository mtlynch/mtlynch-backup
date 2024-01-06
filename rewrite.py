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
    root_logger.setLevel(logging.DEBUG)


def configure_global_settings():
    restic.binary_path = 'c:\\restic\\restic.exe'
    restic.password_file = 'C:\\restic\\pass.txt'


def process_repos(repos, exclude_file):
    for repo in repos:
        process_repo(repo, exclude_file)


def process_repo(repo, exclude_files):
    try:
        rewrite(repo, exclude_files[0])
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



def read_repos(repos_path):
    with open(repos_path) as repos_file:
        return json.load(repos_file)


def rewrite(repo, exclude_file):
    logger.info('Rewriting repos at up to %s...', repo['url'])
    set_repo_environment_variables(repo)
    restic.unlock()
    restic.rewrite(exclude_file=exclude_file, forget=True)


def human_size(bytes, units=[' bytes', ' KB', ' MB', ' GB', ' TB']):
    return str(bytes) + units[0] if bytes < 1024 else human_size(
        bytes >> 10, units[1:])


def format_integer(integer):
    return locale.format_string('%d', integer, grouping=True)


def human_time(value, units=['seconds', 'minutes', 'hours']):
    return ('%.1f ' % value) + units[0] if value < 60 else human_time(
        value / 60.0, units[1:])


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
    configure_global_settings()
    if args.restic_path:
        restic.binary_path = args.restic_path
    print_version()
    try:
        repos = read_repos(args.repos_file)
        process_repos(repos, args.exclude_file)
        logger.info('Rewrites complete!')
    finally:
        clear_environment_variables()
        logger.info('Cleared environment variables')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='Restic Backup Rewriter',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--restic-path',
                        help='path to restic binary (if not in PATH)')
    parser.add_argument('--repos-file',
                        required=True,
                        help='JSON file containing a list of backup repos')
    parser.add_argument('--exclude-file', action='append', default=[])
    main(parser.parse_args())
