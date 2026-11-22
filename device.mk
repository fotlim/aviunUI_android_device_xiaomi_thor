#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from xiaomi sm8450-common
TARGET_HAS_UDFPS := true
$(call inherit-product, device/xiaomi/sm8450-common/common.mk)

# Inherit from the proprietary version
$(call inherit-product, vendor/xiaomi/thor/thor-vendor.mk)

# Audio
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio/mixer_paths_waipio_mtp.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/sku_cape/mixer_paths_waipio_mtp.xml \
    $(LOCAL_PATH)/audio/resourcemanager_waipio_mtp.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/sku_cape/resourcemanager_waipio_mtp.xml \
    $(LOCAL_PATH)/audio/usecaseKvManager.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usecaseKvManager.xml

# Camera
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.camera.concurrent.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.concurrent.xml

# Overlay
PRODUCT_PACKAGES += \
    FrameworksResThor \
    NfcResThor \
    SettingsProviderResThor \
    SettingsResThor \
    SystemUIResThor \
    WifiResThor

# Powershare
PRODUCT_PACKAGES += \
    vendor.lineage.powershare-service.default

# Sensors
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.sensor.barometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_cape/android.hardware.sensor.barometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.hifi_sensors.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_cape/android.hardware.sensor.hifi_sensors.xml

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom-caf/wlan \
    hardware/qcom-caf/wlan/qcwcn

# ---------------------------------------------------------------------------
# AviumUI 设备信息（关于本机 页面展示用）
# ---------------------------------------------------------------------------
# 维护者
AVIUM_MAINTAINER := Fotlim & 大肥鱼
# 处理器（SoC）显示名
AVIUM_SETTINGS_SOC_MODEL_NAME := Snapdragon 8+ Gen 1
# 手机型号显示名
AVIUM_SETTINGS_DEVICE_CODENAME := Xiaomi 12S Ultra

# 自研 NFC 读卡器（fotlim），预装进系统
PRODUCT_PACKAGES += \
    NfcReader

# ---------------------------------------------------------------------------
# 音效：DTS AudioSphere / Dirac shoebox / 杜比 DAP
# 全部从官方 vendor 提取（A15 构建的原生 AELI 库，实测可在 A16 正常 dlopen）
# 注意：不预装 MiSound.apk —— 那是 A15 的 Java 应用，装进 priv-app 会卡住开机
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    libmisoundfx \
    lib_misound_asc \
    libshoebox \
    libswdap \
    libswgamedap \
    libswvqe \
    libdapparamstorage \
    dolby_dms_client \
    dolby_dms_service \
    libdlbdsservice \
    dolby_dms_impl

PRODUCT_COPY_FILES += \
    device/xiaomi/thor/audio/misound_asc_model.tflite:$(TARGET_COPY_OUT_VENDOR)/etc/misound_asc_model.tflite \
    device/xiaomi/thor/audio/etc/dax-default.xml:$(TARGET_COPY_OUT_VENDOR)/etc/dolby/dax-default.xml

# ---------------------------------------------------------------------------
# MiuiCamera 6.4（fotlim 修补版）预装为默认相机；Aperture 由
# lineage_thor.mk 的 PRODUCT_NO_CAMERA := true 移除
# ---------------------------------------------------------------------------
# [ROM-INTEGRATION] 改用 GSQ2004 的 ROM 源码集成版 MIUI 相机（ThorMiuiCamera）
# fotlim 6.4 (MiuiCameraThor) 与集成版同为 com.android.camera，不能共存，故移除。
# 如需回退：恢复 device.mk.bak_romint 并删除下方 inherit-product 行。

# ---------------------------------------------------------------------------
# MIUI 相册/编辑器 兼容：共享库声明（micloud-sdk 为相册 required 依赖）
# 类实体在 frameworks/base/media/java/miui（已加入 framework.jar）；
# 这些 jar 仅用于满足 uses-library 安装校验。
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/miui_compat/com.miui.rom.jar:system/framework/com.miui.rom.jar \
    $(LOCAL_PATH)/miui_compat/com.miui.system.jar:system/framework/com.miui.system.jar \
    $(LOCAL_PATH)/miui_compat/micloud-sdk.jar:system/framework/micloud-sdk.jar \
    $(LOCAL_PATH)/miui_compat/miui-cameraopt.jar:system/framework/miui-cameraopt.jar \
    $(LOCAL_PATH)/miui_compat/miui-compat.xml:system/etc/permissions/miui-compat.xml

# MIUI 相册 + 编辑器 预装（Xiaomi 签名，presigned，product app）
PRODUCT_PACKAGES += \
    MiuiGallery \
    MiuiMediaEditor

# 预置权限：相册/编辑器常用权限开机即授（免首启权限弹窗）
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/miui_compat/miui-default-permissions.xml:system/etc/default-permissions/miui-default-permissions.xml

# >>> miui_gallery libs
# 相册/编辑 APK 声明 extractNativeLibs=true，但预装应用不会自动解压；
# 这里把 lib/arm64-v8a 的 .so 解出来单独装到 <app>/lib/arm64/，否则点开图片会
# UnsatisfiedLinkError: BindCPUCoreUtils.bindCPU (libbindcore.so 无法加载)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/miui_gallery/lib64/libClipPostSDK.so:product/app/MiuiGallery/lib/arm64/libClipPostSDK.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libGalleryFrameRetriever.so:product/app/MiuiGallery/lib/arm64/libGalleryFrameRetriever.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libHDR.so:product/app/MiuiGallery/lib/arm64/libHDR.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libMiMainColor.so:product/app/MiuiGallery/lib/arm64/libMiMainColor.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libVideoRetrieval.so:product/app/MiuiGallery/lib/arm64/libVideoRetrieval.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libbindcore.so:product/app/MiuiGallery/lib/arm64/libbindcore.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libc++_shared.so:product/app/MiuiGallery/lib/arm64/libc++_shared.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libgallery_block_sdk.so:product/app/MiuiGallery/lib/arm64/libgallery_block_sdk.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libjniloader.so:product/app/MiuiGallery/lib/arm64/libjniloader.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmievent.so:product/app/MiuiGallery/lib/arm64/libmievent.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmigalleryffmpeg.so:product/app/MiuiGallery/lib/arm64/libmigalleryffmpeg.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmiocr.so:product/app/MiuiGallery/lib/arm64/libmiocr.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmiocr_wrapper.so:product/app/MiuiGallery/lib/arm64/libmiocr_wrapper.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmitranscoder.so:product/app/MiuiGallery/lib/arm64/libmitranscoder.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libmmkv.so:product/app/MiuiGallery/lib/arm64/libmmkv.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libnexcralbody_mc_jb.so:product/app/MiuiGallery/lib/arm64/libnexcralbody_mc_jb.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libnexeditorsdk.so:product/app/MiuiGallery/lib/arm64/libnexeditorsdk.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libretriever_phone.so:product/app/MiuiGallery/lib/arm64/libretriever_phone.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libsqliteX.so:product/app/MiuiGallery/lib/arm64/libsqliteX.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libvideo_converter.so:product/app/MiuiGallery/lib/arm64/libvideo_converter.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libvideo_extra_color_converter.so:product/app/MiuiGallery/lib/arm64/libvideo_extra_color_converter.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libvideo_extra_interpolator.so:product/app/MiuiGallery/lib/arm64/libvideo_extra_interpolator.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libvideo_extra_interpolator_mialgo.so:product/app/MiuiGallery/lib/arm64/libvideo_extra_interpolator_mialgo.so \
    $(LOCAL_PATH)/miui_gallery/lib64/libvlcjni.so:product/app/MiuiGallery/lib/arm64/libvlcjni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libCNamaSDK.so:product/app/MiuiMediaEditor/lib/arm64/libCNamaSDK.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libCameraToolJNI.so:product/app/MiuiMediaEditor/lib/arm64/libCameraToolJNI.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libFaceBeautyWrapper.so:product/app/MiuiMediaEditor/lib/arm64/libFaceBeautyWrapper.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libMiFilterSDK.so:product/app/MiuiMediaEditor/lib/arm64/libMiFilterSDK.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libMiVideoSDK.so:product/app/MiuiMediaEditor/lib/arm64/libMiVideoSDK.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libXmStreamingSDK.so:product/app/MiuiMediaEditor/lib/arm64/libXmStreamingSDK.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libaiedit.so:product/app/MiuiMediaEditor/lib/arm64/libaiedit.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libarcsoft_dualcam_refocus.so:product/app/MiuiMediaEditor/lib/arm64/libarcsoft_dualcam_refocus.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libavif_android.so:product/app/MiuiMediaEditor/lib/arm64/libavif_android.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libbitmap_util.so:product/app/MiuiMediaEditor/lib/arm64/libbitmap_util.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libc++.so:product/app/MiuiMediaEditor/lib/arm64/libc++.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libc++_shared.so:product/app/MiuiMediaEditor/lib/arm64/libc++_shared.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libcameraheif.so:product/app/MiuiMediaEditor/lib/arm64/libcameraheif.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libcloud_text_loader.so:product/app/MiuiMediaEditor/lib/arm64/libcloud_text_loader.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libdoc_photo_process.so:product/app/MiuiMediaEditor/lib/arm64/libdoc_photo_process.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libext108m.so:product/app/MiuiMediaEditor/lib/arm64/libext108m.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libfuai.so:product/app/MiuiMediaEditor/lib/arm64/libfuai.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libgallery_block_sdk.so:product/app/MiuiMediaEditor/lib/arm64/libgallery_block_sdk.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libheif_jni.so:product/app/MiuiMediaEditor/lib/arm64/libheif_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libinpaint.so:product/app/MiuiMediaEditor/lib/arm64/libinpaint.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libinpaint_jni.so:product/app/MiuiMediaEditor/lib/arm64/libinpaint_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/liblog.so:product/app/MiuiMediaEditor/lib/arm64/liblog.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libmegvii_bokeh_jni.so:product/app/MiuiMediaEditor/lib/arm64/libmegvii_bokeh_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libmegvii_single_bokeh_jni.so:product/app/MiuiMediaEditor/lib/arm64/libmegvii_single_bokeh_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libmi_portrait_jni.so:product/app/MiuiMediaEditor/lib/arm64/libmi_portrait_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libmiffmpeg.so:product/app/MiuiMediaEditor/lib/arm64/libmiffmpeg.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libmpbase.so:product/app/MiuiMediaEditor/lib/arm64/libmpbase.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libpendant.so:product/app/MiuiMediaEditor/lib/arm64/libpendant.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libqcloud-avif.so:product/app/MiuiMediaEditor/lib/arm64/libqcloud-avif.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/librefocus.so:product/app/MiuiMediaEditor/lib/arm64/librefocus.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/librender_engine.so:product/app/MiuiMediaEditor/lib/arm64/librender_engine.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libresource_loader.so:product/app/MiuiMediaEditor/lib/arm64/libresource_loader.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libsdk_patcher_jni.so:product/app/MiuiMediaEditor/lib/arm64/libsdk_patcher_jni.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libturbojpeg.so:product/app/MiuiMediaEditor/lib/arm64/libturbojpeg.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libvis.so:product/app/MiuiMediaEditor/lib/arm64/libvis.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libwatermark-service.so:product/app/MiuiMediaEditor/lib/arm64/libwatermark-service.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libwatermark_effect.so:product/app/MiuiMediaEditor/lib/arm64/libwatermark_effect.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libxcrash.so:product/app/MiuiMediaEditor/lib/arm64/libxcrash.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libxcrash_dumper.so:product/app/MiuiMediaEditor/lib/arm64/libxcrash_dumper.so \
    $(LOCAL_PATH)/miui_gallery/lib64_editor/libyuv.so:product/app/MiuiMediaEditor/lib/arm64/libyuv.so
# <<< miui_gallery libs

# ROM 集成版 MIUI 相机（GSQ2004/thor-miuicamera + AviumUI 修正版）
# APK = 5e1816cf（已修 CTA + 预览桥 ZoomMapBridge）、HAL = 240610b0、白名单 69 条
$(call inherit-product, vendor/xiaomi/thor-miuicamera/product.mk)
