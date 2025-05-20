#!/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Adjust these if you want to deploy a different flavor/build or your APK name/path differs !!!
FLAVOR_NAME="core" # e.g., core, foss, prepaid
BUILD_TYPE="debug" # e.g., debug, release

# APK_NAME will be determined after finding the file
APK_DIR="app/build/outputs/apk/${FLAVOR_NAME}/${BUILD_TYPE}"
GRADLE_TASK=":app:assemble${FLAVOR_NAME^}${BUILD_TYPE^}" # Capitalizes first letter of flavor and build type

echo "🚀 Starting Build and Deploy Process..."
echo "   APK Output Directory: ${APK_DIR}"
echo "   Gradle Task: ${GRADLE_TASK}"
echo ""

# 1. Build APK
echo "🔧 Building APK using task '${GRADLE_TASK}'..."
./gradlew ${GRADLE_TASK}
BUILD_STATUS=$?

if [ ${BUILD_STATUS} -ne 0 ]; then
    echo "❌ APK Build FAILED. Exit code: ${BUILD_STATUS}. Aborting."
    exit 1
fi

echo "🔍 Searching for APK in directory: ${APK_DIR}"
APK_PATH=$(find "${APK_DIR}" -maxdepth 1 -name "*.apk" -type f | head -n 1)

if [ -z "${APK_PATH}" ]; then
    echo "❌ No APK found in directory '${APK_DIR}' after build command."
    echo "   Please check if the build task '${GRADLE_TASK}' actually produced an APK in this location."
    echo "--- Debug Info ---"
    ALL_FLAVOR_APKS_PARENT_DIR="app/build/outputs/apk/${FLAVOR_NAME}"
    if [ -d "${ALL_FLAVOR_APKS_PARENT_DIR}" ]; then
        echo "ℹ️ Contents of parent output directory ${ALL_FLAVOR_APKS_PARENT_DIR} (for flavor '${FLAVOR_NAME}'):"
        ls -R "${ALL_FLAVOR_APKS_PARENT_DIR}"
    else
        echo "ℹ️ Parent output directory ${ALL_FLAVOR_APKS_PARENT_DIR} does not exist."
    fi
    echo "ℹ️ All APKs found under app/build/outputs/apk/ (recursive):"
    find app/build/outputs/apk -name "*.apk" -type f
    echo "--- End Debug Info ---"
    exit 1
fi

APK_NAME=$(basename "${APK_PATH}") # Get the actual name of the found APK for messages

echo "✅ APK Found: ${APK_PATH}"
echo ""

# 2. Check for connected and ready devices
echo "📱 Checking for connected and ready devices..."
# List devices in 'device' state (ready for commands), filter out emulators if desired using -e with grep
# For now, take any 'device' state entry.
READY_DEVICES_OUTPUT=$(adb devices | grep -w 'device$')

if [ -z "${READY_DEVICES_OUTPUT}" ]; then
    echo "⚠️ No ADB devices/emulators found connected and in a 'device' state."
    echo "   Please ensure a device is connected, powered on, USB debugging enabled, and authorized."
else
    # Count how many ready devices
    NUM_READY_DEVICES=$(echo "${READY_DEVICES_OUTPUT}" | wc -l)
    echo "✅ Found ${NUM_READY_DEVICES} ready device(s)."

    # Get the ID of the first ready device
    # awk '{print $1}' gets the first column (device ID)
    FIRST_DEVICE_ID=$(echo "${READY_DEVICES_OUTPUT}" | head -n 1 | awk '{print $1}')
    echo "   Targeting device: ${FIRST_DEVICE_ID}"
    echo ""

    # 3. Send APK to phone
    echo "📲 Deploying '${APK_NAME}' to '${FIRST_DEVICE_ID}'..."
    adb -s "${FIRST_DEVICE_ID}" install -r -t "${APK_PATH}" # Added -t to allow test APKs if needed
    INSTALL_STATUS=$?

    if [ ${INSTALL_STATUS} -ne 0 ]; then
        echo "❌ APK Installation FAILED on '${FIRST_DEVICE_ID}'. Exit code: ${INSTALL_STATUS}."
        echo "   Common issues: APK already installed with a different signature (try uninstalling first),"
        echo "   insufficient storage on device, or APK is invalid/corrupted."
    else
        echo "✅ APK Installed Successfully on '${FIRST_DEVICE_ID}'!"
    fi
fi

# 4. Sleep
echo ""
echo "⏳ Sleeping for 3 seconds so you can review the output..."
sleep 3
echo "👍 Script Finished." 