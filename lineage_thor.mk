#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from thor device
$(call inherit-product, device/xiaomi/thor/device.mk)

# 移除 LineageOS 自带相机 Aperture（我们预装 MiuiCameraThor）
PRODUCT_NO_CAMERA := false

# Inherit from common lineage configuration
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_thor
PRODUCT_DEVICE := thor
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := 2203121C

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="thor-user 15 AQ3A.250226.002 OS3.0.6.0.VLACNXM release-keys" \
    BuildFingerprint=Xiaomi/thor/thor:15/AQ3A.250226.002/OS3.0.6.0.VLACNXM:user/release-keys \
    DeviceProduct=thor \
    SystemName=thor

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# 用小米相册(MiuiGallery)替代 LineageOS 自带相册：从 PRODUCT_PACKAGES 移除 Glimpse / Gallery2
PRODUCT_PACKAGES := $(filter-out Glimpse Gallery2,$(PRODUCT_PACKAGES))
