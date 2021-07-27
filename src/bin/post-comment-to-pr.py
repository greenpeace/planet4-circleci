#!/usr/bin/env python3

import argparse
from datetime import datetime
import os

from p4.github import (get_repo_endpoints, check_for_comment,
                       post_issue_comment, add_issue_label)

if __name__ == '__main__':

    # Options
    parser = argparse.ArgumentParser()
    parser.add_argument("--pr-url",
                        help="pull request URL")
    parser.add_argument("--test-instance",
                        help="test instance used")
    args = parser.parse_args()

    # Parsed options
    pr_url = args.pr_url if args.pr_url else os.getenv('CIRCLE_PULL_REQUEST')
    test_instance = args.test_instance

    # Fetch PR details
    pr_endpoint, comment_endpoint = get_repo_endpoints(pr_url=pr_url)

    # Construct comment body
    now = datetime.now().strftime('%Y.%m.%d %H:%M:%S')
    title = '### Test instance is ready :rocket:'
    msg = (':new_moon: [{0}](https://www-dev.greenpeace.org/test-{0}) | '
           '[admin](https://www-dev.greenpeace.org/test-{0}/wp-admin/) | '
           '[blocks report](https://www-dev.greenpeace.org/test-{0}/wp-admin/?page=plugin_blocks_report) | '
           '[CircleCI](https://app.circleci.com/pipelines/github/greenpeace/planet4-test-{0}) | '
           '[composer-local.json](https://github.com/greenpeace/planet4-test-{0}/blob/main/composer-local.json)\n\n'
           ':watch: {1}').format(
            test_instance, now)
    body = '{0}\n\n{1}'.format(title, msg)

    # Post comment, but only once
    comment_id = check_for_comment(pr_endpoint, title)
    post_issue_comment(pr_endpoint, comment_endpoint, comment_id, body)

    # Add label
    label_name = '[Test Env] {0}'.format(test_instance)
    add_issue_label(pr_endpoint, label_name)

    print("Comment posted")

