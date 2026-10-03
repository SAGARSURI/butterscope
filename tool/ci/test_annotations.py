#!/usr/bin/env python3
"""Turns a test run's JSON report into GitHub Actions annotations.

Usage: test_annotations.py <report.json> <package dir>

The report is what `dart test` or `flutter test` writes with
`--file-reporter json:<path>`; its format is documented at
https://github.com/dart-lang/test/blob/master/pkgs/test/doc/json_reporter.md

Prints one `::error` workflow command per test error, placed on the line
that declares the failing test, so the failure shows beside it in a pull
request. Prints nothing when the report is missing or has no errors; the
caller then falls back to a summary annotation. Always exits 0.
"""

import json
import os
import sys
from urllib.parse import unquote, urlparse


def escape(text, is_property=False):
    """Escapes text for a workflow command message or property value."""
    text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    if is_property:
        text = text.replace(':', '%3A').replace(',', '%2C')
    return text


def repo_path(location, package_dir):
    """A file URL or a package-relative path, relative to the repo root."""
    if not location:
        return None
    if location.startswith('file://'):
        path = unquote(urlparse(location).path)
    else:
        path = os.path.join(package_dir, location)
    return os.path.relpath(os.path.abspath(path), os.getcwd())


def main(report, package_dir):
    if not os.path.exists(report):
        return
    suites, tests, errors = {}, {}, []
    with open(report, encoding='utf-8') as lines:
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = event.get('type')
            if kind == 'suite':
                suites[event['suite']['id']] = event['suite']
            elif kind == 'testStart':
                tests[event['test']['id']] = event['test']
            elif kind == 'error':
                errors.append(event)

    for error in errors:
        test = tests.get(error.get('testID'), {})
        # root_* point into the test file when the test was declared through
        # a helper in another file.
        location = test.get('root_url') or test.get('url')
        line = test.get('root_line') or test.get('line')
        if not location:
            # A suite that failed to load has no test location; use its file.
            location = suites.get(test.get('suiteID'), {}).get('path')
            line = None

        properties = []
        path = repo_path(location, package_dir)
        if path:
            properties.append('file=' + escape(path, is_property=True))
            if line:
                properties.append('line=%d' % line)
        name = test.get('name') or 'test'
        properties.append('title=' + escape(name, is_property=True))
        message = '%s\n\n%s' % (error.get('error', ''), error.get('stackTrace', ''))
        print('::error %s::%s' % (','.join(properties), escape(message.strip())))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
