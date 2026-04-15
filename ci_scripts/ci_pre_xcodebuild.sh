#!/bin/sh
# ci_pre_xcodebuild.sh — runs in Xcode Cloud right before xcodebuild starts.
#
# Sets CURRENT_PROJECT_VERSION to the Xcode Cloud build number so every
# TestFlight upload has a unique build number. Without this, Apple rejects
# uploads that reuse an existing build number.
#
# Xcode Cloud runs this script from the ci_scripts/ subdirectory, so we
# must cd to the repo root (CI_PRIMARY_REPOSITORY_PATH) before touching
# the project file. agvtool is intentionally NOT used here — it requires
# apple-generic versioning, which DocArmor doesn't use, and exits with
# code 3 when the convention isn't met. Direct sed is more reliable.

set -e

# Only run inside Xcode Cloud (CI_BUILD_NUMBER is set by the system).
if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "Not running in Xcode Cloud — skipping build number update."
    exit 0
fi

echo "Setting build number to $CI_BUILD_NUMBER"

# Move to the repo root where the .xcodeproj lives.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Directly patch every CURRENT_PROJECT_VERSION entry in the project file.
find . -name "project.pbxproj" -exec \
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/g" {} +

if [ -n "$CI_GIT_COMMIT_SHA" ]; then
    SHORT_SHA=$(echo "$CI_GIT_COMMIT_SHA" | cut -c1-8)
    echo "Git commit: $SHORT_SHA"
fi

echo "Build number updated to $CI_BUILD_NUMBER in project.pbxproj"
