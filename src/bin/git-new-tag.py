#!/usr/bin/env python3
from git import Repo, exc
import os
import sys
import semver
from shutil import rmtree

REPO_PREFIX_URL='git@github.com:greenpeace/'


def bump_version(text, prefix='v'):
  """
  Takes a tag number as an argument and increments the minor version.
  """

  # Remove version prefix
  if text.startswith(prefix):
    text = text[len(prefix):]

  # Convert to semver
  if len(text.split('.')) < 3:
    text = '{0}.0'.format(text)

  # Bump minor
  ver = semver.VersionInfo.parse(text)
  next_ver = 'v{0}'.format(str(ver.bump_minor()))

  return next_ver


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print('Arguments are missing.\n Syntax: {0} <repo-name> [<path>]'.format(sys.argv[0]))
        exit(1)

    repo_url = '{0}{1}.git'.format(REPO_PREFIX_URL, sys.argv[1])

    try:
      repo_path = sys.argv[2]
    except IndexError:
      repo_path = sys.argv[1]

    try:
      rmtree(repo_path)
    except FileNotFoundError:
      pass

    repo=Repo.clone_from(repo_url, repo_path)

    new_tag = bump_version(str(repo.tags[-1]))
    repo.create_tag(new_tag, message=new_tag)

    origin = repo.remote('origin')
    response = origin.push(new_tag)[0]
    print(response.summary)

    exit(0)
