#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-release}"
CONFIGURATION="${MODE}"
TEAM_ID="52A6FA9VB5"
APP_IDENTITY="3rd Party Mac Developer Application: Magnus Egelberg (${TEAM_ID})"
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Magnus Egelberg (${TEAM_ID})"
if [[ "${MODE}" == "app-store" ]]; then
  CONFIGURATION="release"
fi
APP_NAME="Broker Explorer"
EXECUTABLE_NAME="BrokerExplorer"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
OUTPUT_APP_DIR="${APP_DIR}"
if [[ "${MODE}" == "app-store" ]]; then
  # Sign outside file-provider folders, which can reintroduce Finder attributes.
  STAGING_DIR="$(mktemp -d /private/tmp/broker-explorer.XXXXXX)"
  trap 'rm -rf "${STAGING_DIR}"' EXIT
  APP_DIR="${STAGING_DIR}/${APP_NAME}.app"
fi
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

if [[ "${CONFIGURATION}" != "debug" && "${CONFIGURATION}" != "release" ]]; then
  echo "Usage: Scripts/build-app.sh [debug|release|app-store]" >&2
  exit 1
fi

if [[ "${MODE}" == "app-store" ]]; then
  if ! security find-identity -v -p codesigning | grep -Fq "\"${APP_IDENTITY}\""; then
    echo "Missing valid signing identity: ${APP_IDENTITY}" >&2
    exit 1
  fi
  # Never leave an older upload package alongside a newly built application.
  rm -f "${ROOT_DIR}/dist/${APP_NAME}.pkg"
fi

cd "${ROOT_DIR}"

if [[ "${CONFIGURATION}" == "release" ]]; then
  swift build -c release
else
  swift build
fi

BUILD_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
# Stamp the actual bundle, leaving the release version and source plist unchanged.
BUILD_NUMBER="$(TZ=UTC date '+%Y%m%d%H%M%S')"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${CONTENTS_DIR}/Info.plist"
cp "${ROOT_DIR}/Resources/BrokerExplorerIcon.icns" "${RESOURCES_DIR}/BrokerExplorerIcon.icns"
cp "${ROOT_DIR}/Resources/PrivacyInfo.xcprivacy" "${RESOURCES_DIR}/PrivacyInfo.xcprivacy"
# SwiftPM builds resource bundles beside its executable; preserve their manifests.
for RESOURCE_BUNDLE in "${BUILD_DIR}"/*.bundle; do
  [[ -d "${RESOURCE_BUNDLE}" ]] || continue
  ditto "${RESOURCE_BUNDLE}" "${RESOURCES_DIR}/$(basename "${RESOURCE_BUNDLE}")"
done
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"

echo "Built ${APP_DIR}"

if [[ "${MODE}" != "app-store" ]]; then
  exit 0
fi

# SwiftPM resource files may be read-only; only make the assembled copy writable.
chmod -R u+w "${APP_DIR}"
xattr -cr "${APP_DIR}"
codesign --force --sign "${APP_IDENTITY}" \
  --entitlements "${ROOT_DIR}/Resources/BrokerExplorer.entitlements" "${APP_DIR}"
codesign --verify --strict --verbose=2 "${APP_DIR}"
SIGNATURE="$(codesign --display --verbose=4 "${APP_DIR}" 2>&1)"
if ! grep -Fxq "TeamIdentifier=${TEAM_ID}" <<< "${SIGNATURE}"; then
  echo "Signed app does not have expected Team ID ${TEAM_ID}." >&2
  exit 1
fi
if ! grep -Fxq "Authority=${APP_IDENTITY}" <<< "${SIGNATURE}"; then
  echo "Signed app does not have expected distribution identity." >&2
  exit 1
fi
# Compare the actual signed entitlements, not just the source file.
ACTUAL_ENTITLEMENTS="$(codesign --display --entitlements - --xml "${APP_DIR}" | plutil -convert xml1 -o - -)"
EXPECTED_ENTITLEMENTS="$(plutil -convert xml1 -o - "${ROOT_DIR}/Resources/BrokerExplorer.entitlements")"
if [[ "${ACTUAL_ENTITLEMENTS}" != "${EXPECTED_ENTITLEMENTS}" ]]; then
  echo "Signed entitlements differ from BrokerExplorer.entitlements." >&2
  exit 1
fi
echo "Verified distribution app for team ${TEAM_ID}."
mkdir -p "${ROOT_DIR}/dist"
rm -rf "${OUTPUT_APP_DIR}"
ditto --norsrc "${APP_DIR}" "${OUTPUT_APP_DIR}"
xattr -cr "${OUTPUT_APP_DIR}"
codesign --verify --strict --verbose=2 "${OUTPUT_APP_DIR}"
echo "Signed application: ${OUTPUT_APP_DIR}"

# Installer certificates are not included in the codesigning-policy identity list.
if ! security find-identity -v | grep -Fq "\"${INSTALLER_IDENTITY}\""; then
  echo "Application is signed and verified; package creation stopped." >&2
  echo "Install a Mac Installer Distribution certificate with its private key:" >&2
  echo "${INSTALLER_IDENTITY}" >&2
  exit 1
fi
PKG_PATH="${ROOT_DIR}/dist/${APP_NAME}.pkg"
productbuild --sign "${INSTALLER_IDENTITY}" --component "${APP_DIR}" /Applications "${PKG_PATH}"
pkgutil --check-signature "${PKG_PATH}"
echo "Built signed package ${PKG_PATH}"
