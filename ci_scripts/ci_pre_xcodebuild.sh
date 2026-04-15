#!/bin/sh
# Runs before Xcode build in Xcode Cloud
set -e

# Bump build number using CI_BUILD_NUMBER provided by Xcode Cloud
if [ -n "$CI_BUILD_NUMBER" ]; then
  echo "Setting build number to $CI_BUILD_NUMBER"
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi

# Set version (optional)
if [ -n "$CI_GIT_COMMIT_SHA" ]; then
  SHORT_SHA=$(echo "$CI_GIT_COMMIT_SHA" | cut -c1-8)
  echo "Git commit: $SHORT_SHA"
fi

echo "Pre-build setup complete"
