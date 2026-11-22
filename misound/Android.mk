LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := MiSound
LOCAL_MODULE_OWNER := fotlim
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := MiSound.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_PRIVILEGED_MODULE := true
LOCAL_DEX_PREOPT := false
# [fish] MiSound.apk 的 <uses-library> 是 required=false，必须在这里声明一致，
# 否则 enforce_uses_libraries 检查会报 mismatch 并让整个 ninja 失败。
LOCAL_OPTIONAL_USES_LIBRARIES := com.miui.core androidx.window.extensions androidx.window.sidecar
include $(BUILD_PREBUILT)
