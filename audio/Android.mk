LOCAL_PATH := $(call my-dir)

# ===== AELI 音效库（从官方 vendor 提取，64+32 双架构）=====
# 这些是 Android 15 官方镜像里的原生音效库；AELI 接口十多年未变，
# 其中的 libmisoundfx / libasphere 已在 Android 16 上实测可正常 dlopen。

include $(CLEAR_VARS)
LOCAL_MODULE := libmisoundfx
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := soundfx/arm64/libmisoundfx.so
LOCAL_SRC_FILES_32 := soundfx/arm/libmisoundfx.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_RELATIVE_PATH := soundfx
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# libasphere 由 vendor/xiaomi/sm8450-common 的 Android.bp 提供，这里不重复定义

include $(CLEAR_VARS)
LOCAL_MODULE := libshoebox
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := soundfx/arm64/libshoebox.so
LOCAL_SRC_FILES_32 := soundfx/arm/libshoebox.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_RELATIVE_PATH := soundfx
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := libswdap
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := soundfx/arm64/libswdap.so
LOCAL_SRC_FILES_32 := soundfx/arm/libswdap.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_RELATIVE_PATH := soundfx
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := libswgamedap
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := soundfx/arm64/libswgamedap.so
LOCAL_SRC_FILES_32 := soundfx/arm/libswgamedap.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_RELATIVE_PATH := soundfx
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := libswvqe
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := soundfx/arm64/libswvqe.so
LOCAL_SRC_FILES_32 := soundfx/arm/libswvqe.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_RELATIVE_PATH := soundfx
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# ===== 杜比 DAP 参数存储（64+32）=====
include $(CLEAR_VARS)
LOCAL_MODULE := libdapparamstorage
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := lib64/libdapparamstorage.so
LOCAL_SRC_FILES_32 := lib/libdapparamstorage.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# ===== 杜比 DMS HIDL 客户端库（64+32，输出名带 @）=====
include $(CLEAR_VARS)
LOCAL_MODULE := dolby_dms_client
LOCAL_MODULE_STEM_64 := vendor.dolby.hardware.dms@2.0
LOCAL_MODULE_STEM_32 := vendor.dolby.hardware.dms@2.0
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := lib64/vendor.dolby.hardware.dms@2.0.so
LOCAL_SRC_FILES_32 := lib/vendor.dolby.hardware.dms@2.0.so
LOCAL_MULTILIB := both
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# dolby_dms_service 已移到 audio/Android.bp（需要 vintf_fragments + init_rc）

# ===== 小米音效耳机自适应算法库（内嵌 TFLite，64 位）=====
include $(CLEAR_VARS)
LOCAL_MODULE := lib_misound_asc
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES := lib_misound_asc.so
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MULTILIB := 64
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# ===== 杜比 DMS 服务的依赖库（官方 vendor 提取）=====
include $(CLEAR_VARS)
LOCAL_MODULE := libdlbdsservice
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := lib64/libdlbdsservice.so
LOCAL_MULTILIB := 64
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := dolby_dms_impl
LOCAL_MODULE_STEM := vendor.dolby.hardware.dms@2.0-impl
LOCAL_MODULE_OWNER := fotlim
LOCAL_SRC_FILES_64 := lib64/vendor.dolby.hardware.dms@2.0-impl.so
LOCAL_MULTILIB := 64
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_VENDOR_MODULE := true
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)
