import json
import os
import re
import requests

from p4.apis import api_query


GITHUB_API = 'https://api.github.com'


def get_repo_endpoints(pr_url):
    """
    Creates API endpoint for a give PR url
    """

    regex = re.compile('https://github.com/(.*)/pull/([0-9]{1,6})')
    matches = regex.match(pr_url)

    repository = matches.group(1) or None
    pr_number = matches.group(2) or None

    if not repository or not pr_number:
        raise Exception('PR id could not be parsed.')

    pr_endpoint = '{0}/repos/{1}/issues/{2}'.format(
        GITHUB_API,
        repository,
        pr_number
    )

    comment_endpoint = '{0}/repos/{1}/issues/comments/'.format(
        GITHUB_API,
        repository
    )

    return pr_endpoint, comment_endpoint


def check_for_comment(pr_endpoint, title):
    oauth_key = os.getenv('GITHUB_OAUTH_TOKEN')

    headers = {
        'Authorization': 'token {0}'.format(oauth_key),
        'Accept': 'application/vnd.github.v3+json'
    }

    comments_endpoint = '{0}/comments'.format(pr_endpoint)

    response = requests.get(comments_endpoint, headers=headers)

    for comment in response.json():
        if comment['body'].splitlines()[0] == title:
            return comment['id']

    return False


def get_last_commit_date(repo):
    """
    Return last commit date for a repo.
    """
    commit = api_query(
        GITHUB_API + '/repos/' + repo + '/commits/main',
        {'Accept': 'application/vnd.github.v3+json'}
    )

    return commit['commit']['committer']['date']


def post_issue_comment(pr_endpoint, comment_endpoint, comment_id, body):
    oauth_key = os.getenv('GITHUB_OAUTH_TOKEN')

    data = {
        'body': body
    }
    headers = {
        'Authorization': 'token {0}'.format(oauth_key),
        'Accept': 'application/vnd.github.v3+json'
    }

    comments_endpoint = '{0}/comments'.format(pr_endpoint)

    if comment_id:
        endpoint = '{0}{1}'.format(comment_endpoint, comment_id)
        response = requests.patch(endpoint, headers=headers, data=json.dumps(data))
        return response.json()

    response = requests.post(comments_endpoint, headers=headers, data=json.dumps(data))
    return response.json()


def add_issue_label(pr_endpoint, label_name):
    oauth_key = os.getenv('GITHUB_OAUTH_TOKEN')

    data = {
        'labels': [label_name]
    }
    headers = {
        'Authorization': 'token {0}'.format(oauth_key),
        'Accept': 'application/vnd.github.v3+json'
    }

    labels_endpoint = '{0}/labels'.format(pr_endpoint)

    response = requests.post(labels_endpoint, headers=headers, data=json.dumps(data))
    return response.json()


def get_pr_test_instance(pr_endpoint, prefix='[Test Env] '):
    oauth_key = os.getenv('GITHUB_OAUTH_TOKEN')

    headers = {
        'Authorization': 'token {0}'.format(oauth_key),
        'Accept': 'application/vnd.github.v3+json'
    }

    response = requests.get(pr_endpoint, headers=headers)

    labels = response.json()['labels']

    for label in labels:
        if label['name'].startswith(prefix):
            return label['name'][len(prefix):]

    return False