#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        odm/bin/hw/vendor.ozoaudio.media.c2@1.0-service|odm/lib/libcodec2_soft_ozodec.so|odm/lib/libcodec2_soft_ozoenc.so)
            "${PATCHELF}" --add-needed "libshims_ozoc2store.so" "${2}"
            ;;
        odm/etc/init/vendor.ozoaudio.media.c2@1.0-service.rc)
            cat << EOF >> "${2}"
    disabled
EOF
            ;;
        odm/etc/init/vendor.oplus.hardware.oplusSensor@1.0-service.rc)
            sed -i "/user/ s/system/root/g" "${2}"
            ;;
        odm/lib/liblvimfs_wrapper.so|odm/lib64/libCOppLceTonemapAPI.so|vendor/lib64/libalsc.so)
            "${PATCHELF}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;
        system_ext/etc/permissions/com.android.hotwordenrollment.common.util.xml)
            sed -i "s/my_product/system_ext/" "${2}"
            ;;
        vendor/etc/msm_irqbalance.conf)
            sed -i "s/IGNORED_IRQ=27,23,38$/&,115,332/" "${2}"
            ;;
        vendor/lib64/hw/camera.qcom.so)
            grep -q libcamera_metadata_shim.so "${2}" || "${PATCHELF}" --add-needed "libcamera_metadata_shim.so" "${2}"
            ;;
        vendor/etc/msm_irqbalance.conf)
            sed -i "s/IGNORED_IRQ=27,23,38$/&,115,332/" "${2}"
            ;;
        vendor/etc/init/android.hardware.neuralnetworks@1.3-service-qti.rc)
            sed -i "s|writepid /dev/stune/nnapi-hal/tasks|task_profiles NNApiHALPerformance|g" "${2}"
            ;;
        vendor/lib64/vendor.qti.hardware.camera.postproc@1.0-service-impl.so)
            "${SIGSCAN}" -p "AF 0B 00 94" -P "1F 20 03 D5" -f "${2}"
            ;;
	    odm/lib64/libAlgoProcess.so)
            patchelf --replace-needed "android.hardware.graphics.common-V1-ndk_platform.so" "android.hardware.graphics.common-V1-ndk.so" "${2}"
            ;;
        vendor/lib/libgui1_vendor.so)
            "${PATCHELF}" --replace-needed "libui.so" "libui-v30.so" "${2}"
            ;;
        vendor/lib64/libril-qc-hal-qmi.so)
            "${PATCHELF}" --add-needed "libshims_ocsclk.so" "${2}"
            ;;
        odm/lib64/libwvhidl.so|odm/lib64/mediadrm/libwvdrmengine.so|odm/lib64/libdmtp.so|odm/lib64/libdmtpclient.so|odm/lib64/libdmtp-protos-lite.so|odm/lib64/lib-virtual-modem-protos.so|odm/lib64/liboplus_service.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        vendor/lib64/libssc.so|vendor/lib64/libsensorcal.so|vendor/lib64/sensors.ssc.so|vendor/lib64/libsnsdiaglog.so|vendor/lib64/libsnsapi.so|vendor/bin/sensors.qti)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        odm/lib/libdlbdsservice_v3_6.so | odm/lib/libstagefright_soft_ddpdec.so | odm/lib/libstagefrightdolby.so | odm/lib64/libdlbdsservice_v3_6.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
    esac
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
