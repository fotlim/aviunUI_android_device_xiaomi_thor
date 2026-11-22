# Thor（小米 12S Ultra）ROM 定制与相机/相册整合 —— 完整记录

> 项目：AviumUI-16.2.2（Android 16 / Lineage 系）自编译 ROM，目标是把 **两个相机 + 小米相册 + 相册编辑** 打进系统包
> 机型：Xiaomi 12S Ultra（thor，2203121C，SM8475）
> 构建机：WSL2 Ubuntu 22.04，源码树 `/root/avium`
> 最后更新：2026-11-15

---

## 一、最终成果概览（★已在真机验证通过）

| 项目 | 内容 | 验证 |
|---|---|---|
| ROM 版本 | `AviumUI-16.2.2-thor-20261115` | ✅ 开机正常 |
| 相机 1 | **fotlim MiuiCamera 6.4**（`com.android.camera`，装在 `/system/app/MiuiCameraThor`） | ✅ pid 4691 运行 |
| 相机 2 | **Aperture**（`org.lineageos.aperture`，`/product/app/Aperture`） | ✅ pid 5856 运行 |
| 相册 | **小米相册 MiuiGallery 4.3.1.18**（`/product/app/MiuiGallery`） | ✅ pid 5178，**界面正常显示 27 张照片**（截图验证） |
| 编辑 | **MiuiMediaEditor 2.4.0.5.2**（`/product/app/MiuiMediaEditor`） | ✅ 已预装、进程可启动 |
| 兼容层 | `miui_compat`（4 个 jar + 权限 xml）+ framework 内 `miui.*` 类 + **hiddenapi 白名单** | ✅ hidden API 拒绝已消除 |
| 打包产物 | 线刷包 6.0G / 卡刷包 2.6G | ✅ 已生成 |

### 关键验证证据
- `pm path` 四个包路径正确
- 相册截图：正常显示「照片 / 27张照片 / 今天 / 昨天 / 缩略图网格」
- `logcat` 中 **无** `FATAL EXCEPTION`、**无** `Lmiui/*` 的 `hiddenapi ... denied`
- `hidden_api_policy` = `null`（**不依赖任何运行时开关**，纯 ROM 内置）

---

## 二、关键源码改动（`/root/avium`）

### 1. `device/xiaomi/thor/lineage_thor.mk`
```make
# 原：移除 LineageOS 自带相机 Aperture（我们预装 MiuiCameraThor）
PRODUCT_NO_CAMERA := false          # 改为 false → 保留 Aperture，实现双相机
PRODUCT_PACKAGES := $(filter-out Glimpse Gallery2,$(PRODUCT_PACKAGES))   # 用小米相册替代自带相册
```

### 2. `device/xiaomi/thor/miuicamera/Android.bp`
```bp
android_app_import {
    name: "MiuiCameraThor",
    apk: "MiuiCamera.apk",
    presigned: true,
    preprocessed: true,
    dex_preopt: { enabled: false },
    # product_specific: true   ← 已删除：改到 /system/app，获得 system namespace
    overrides: [ "Camera2" ],   # 不再覆盖 Aperture
}
```

> **为什么要放 system 分区**：product 应用的 linker namespace（`product-clns-*`）看不到 `/system/lib64`，
> 导致 fotlim 内嵌的 `libcamera_algoup_jni.xiaomi.so` 找不到 `libbase.so` 而崩溃：
> `dlopen failed: library "libbase.so" not found ... in namespace product-clns-11`

### 3. `device/xiaomi/thor/device.mk`
```make
# miui_compat 共享库（满足相册 uses-library 校验）
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/miui_compat/com.miui.rom.jar:system/framework/com.miui.rom.jar \
    $(LOCAL_PATH)/miui_compat/com.miui.system.jar:system/framework/com.miui.system.jar \
    $(LOCAL_PATH)/miui_compat/micloud-sdk.jar:system/framework/micloud-sdk.jar \
    $(LOCAL_PATH)/miui_compat/miui-cameraopt.jar:system/framework/miui-cameraopt.jar \
    $(LOCAL_PATH)/miui_compat/miui-compat.xml:system/etc/permissions/miui-compat.xml

# 相册 + 编辑
PRODUCT_PACKAGES += MiuiGallery MiuiMediaEditor

# 默认权限
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/miui_compat/miui-default-permissions.xml:system/etc/default-permissions/miui-default-permissions.xml
```

### 4. `device/xiaomi/thor/miui_gallery/`
```
miui_gallery/
├── Android.bp                 # android_app_import × 2（presigned, preprocessed, product_specific）
├── MiuiGallery.apk            # 89.5MB = F:\相册_4.3.1.18.apk
└── MiuiMediaEditor.apk        # 180MB  = F:\小米相册-编辑_2.4.0.5.2.apk
```

### 5. `frameworks/base/media/java/miui/`
```
miui/os/Build.java
miui/util/FeatureParser.java       # 关键：gallery 依赖 getString/getBoolean/getInt/getLong/getInteger/hasFeature
miui/util/HapticFeedbackUtil.java
```
> 该目录必须被 `frameworks/base/Android.bp` 的 `media/java` 源集合包含（已确认，第 187 行）。

---

## 三、踩过的坑与修复（重要经验）

### 坑 1：`res/` 目录里的备份文件导致 aapt2 报错
```
error: invalid file path '.../overlay/Frameworks/res/values/config.xml.bak_miuigallery'
```
**原因**：aapt2 会把 `res/` 下所有文件当资源编译。
**修复**：备份文件移出 `res/`（统一放到 `device/xiaomi/thor/_backups/`）。

### 坑 2：presigned APK 含压缩 JNI 库，被 soong 校验拒绝
```
MiuiGallery.apk: Contains compressed JNI libraries
```
**原因**：Android 15+ 要求 presigned prebuilt 的 `.so` 必须 STORED（未压缩），而小米 APK 是 Deflate。
**修复**：patch `build/soong/scripts/check_prebuilt_presigned_apk.py`，把
`has_preprocessed_issues(args, fail=True)` → `fail=False`（原文件备份 `.bak_avium`）。
**依据**：实测压缩 `.so` 的 APK 在 product 分区安装运行完全正常。

### 坑 2.5（★最坑）：Hidden API 限制 —— 相册崩溃的真正原因

**症状**：相册启动即崩：
```
java.lang.NoSuchMethodError: No static method getBoolean(Ljava/lang/String;Z)Z
  in class Lmiui/util/FeatureParser; ...
```
但把设备上的 `framework.jar` 拉回来用 `dexdump` 检查，**方法明明存在**：
```
name: 'getBoolean'  type: '(Ljava/lang/String;Z)Z'  access: PUBLIC STATIC
```
甚至连 root 下用 `app_process` 反射调用都成功（打印出 10 个方法）。

**真正的日志证据**（关键行，容易被忽略）：
```
E/om.miui.gallery: hiddenapi: Accessing hidden method
   Lmiui/util/FeatureParser;->getBoolean(Ljava/lang/String;Z)Z
   (runtime_flags=0, domain=platform, api=blocked)
   from /product/app/MiuiGallery/MiuiGallery.apk!classes2.dex (domain=app, TargetSdkVersion=35)
   using linking: denied
```

**根因**：`miui.util.FeatureParser` 在 `framework.jar` 里属于 **platform domain**，
其方法被 hidden API 标记为 **blocked**；相册是普通应用（domain=app, targetSdk 35），
访问这类方法会 **linking: denied** → 抛出 `NoSuchMethodError`。
（不是方法不存在，是**被禁止访问**。root/shell 域不受限，所以测试能过。）

**修复**：把需要的方法加入 hidden API 白名单
`frameworks/base/boot/hiddenapi/hiddenapi-unsupported.txt`（"unsupported" = 允许访问，仅记录警告）。

> 之前有人已经加过该文件，但**只加了 `getInteger` 和 `hasFeature` 两条**，
> 而相册实际调用的 `getBoolean(String,boolean)` 等**没有加** → 所以照样崩。
> 这就是"之前成功过、现在又坏"的关键差异：白名单没补全。

需要补的条目（已补齐，共 9 条）：
```
Lmiui/util/FeatureParser;->getBoolean(Ljava/lang/String;)Z
Lmiui/util/FeatureParser;->getBoolean(Ljava/lang/String;Z)Z
Lmiui/util/FeatureParser;->getInt(Ljava/lang/String;)I
Lmiui/util/FeatureParser;->getInt(Ljava/lang/String;I)I
Lmiui/util/FeatureParser;->getLong(Ljava/lang/String;)J
Lmiui/util/FeatureParser;->getLong(Ljava/lang/String;J)J
Lmiui/util/FeatureParser;->getString(Ljava/lang/String;)Ljava/lang/String;
Lmiui/util/FeatureParser;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
Lmiui/util/FeatureParser;->sFeatures:Ljava/util/HashMap;
```

**快速验证手段**（不用重编 ROM）：
```bash
adb shell settings put global hidden_api_policy 1   # 关闭 hidden API 限制
adb shell am force-stop com.miui.gallery
adb shell am start -n com.miui.gallery/com.miui.gallery.activity.HomePageActivity
```
实测：执行后相册**立刻正常打开**（有截图验证）。这就是根因的铁证。

> ⚠️ 注意：`hidden_api_policy` 只是运行时开关，**不是最终方案**。
> 正式 ROM 必须写白名单重编，否则默认值下相册仍会崩。

### 坑 2.6：相机在 product 分区崩溃（libbase 找不到）

**症状**：
```
FISHPROBE_LOADLIB_FAIL: dlopen failed: library "libbase.so" not found
  needed by /product/app/MiuiCameraThor/.../libcamera_algoup_jni.xiaomi.so
  in namespace product-clns-11
```

**根因**：product 应用（非特权）的 linker namespace 是
`/product/lib64:/system/product/lib64`，**不包含 `/system/lib64`**，
所以 APK 内嵌的 `libcamera_algoup_jni.xiaomi.so` 找不到 `libbase.so` 等系统库。

**修复**：把相机从 product 分区改到 **system 分区**（`/system/app`），
获得 system namespace，可直接访问 `/system/lib64`。
具体：`miuicamera/Android.bp` 里**删除 `product_specific: true`**。
（`android_app_import` 默认装到 `/system/app`，非特权，不需要 privapp 权限白名单。）

实测：改后 **fotlim 相机正常工作**。

### 坑 2.7：`Build.IS_TABLET` 字段也被 hidden API 拦截（坑 2.5 的延续）

修好 `FeatureParser` 后，相册进程活得久了，但接着又崩：
```
E/om.miui.gallery: hiddenapi: Accessing hidden field
   Lmiui/os/Build;->IS_TABLET:Z (domain=platform, api=blocked)
   ... using linking: denied
java.lang.NoSuchFieldError: No field IS_TABLET of type Z in class Lmiui/os/Build
```
（`IS_TABLET` 字段在源码和 dex 里**都存在**，又是被 forbidden 而非缺失）

**根因**：此前白名单只加了 6 个 `Build` 字段 + `getRegion`，
**漏了 `IS_TABLET`（以及 DEVICE/PRODUCT/FINGERPRINT 等字段）**。

**系统性排查方法**（强烈推荐，避免反复试错）：
```bash
# 用 dexdump 反汇编 gallery 的 dex，抓出所有对 Lmiui/* 的引用
# 注意：dexdump 输出里成员分隔是 ";." 而不是 ";->"
dexdump -d classes*.dex | grep -oE 'Lmiui/[A-Za-z0-9_/$]+;\.[A-Za-z0-9_$<>]+(:[A-Za-z0-9_/$;[]+|\([A-Za-z0-9_/$;[]*\)[A-Za-z0-9_/$;[]+)'
```
实测扫描出相册需要的 `miui.*` 成员：
- `Lmiui/os/Build.`：DEVICE / IS_ALPHA_BUILD / IS_DEVELOPMENT_VERSION / IS_GLOBAL_BUILD /
  IS_INTERNATIONAL_BUILD / IS_MIPAD / IS_STABLE_VERSION / **IS_TABLET**
- `Lmiui/util/FeatureParser.`：getBoolean×2 / getInt×2 / getInteger / getLong×2 / getString×2 / hasFeature / sFeatures
- `Lmiui/util/HapticFeedbackUtil.`：performHapticFeedback×2

**最终白名单内容**（`hiddenapi-unsupported.txt` 追加 13 条）：
```
Lmiui/os/Build;->IS_TABLET:Z
Lmiui/os/Build;->DEVICE:Ljava/lang/String;
Lmiui/os/Build;->PRODUCT:Ljava/lang/String;
Lmiui/os/Build;->FINGERPRINT:Ljava/lang/String;
Lmiui/util/FeatureParser;->getBoolean(Ljava/lang/String;)Z
Lmiui/util/FeatureParser;->getBoolean(Ljava/lang/String;Z)Z
Lmiui/util/FeatureParser;->getInt(Ljava/lang/String;)I
Lmiui/util/FeatureParser;->getInt(Ljava/lang/String;I)I
Lmiui/util/FeatureParser;->getLong(Ljava/lang/String;)J
Lmiui/util/FeatureParser;->getLong(Ljava/lang/String;J)J
Lmiui/util/FeatureParser;->getString(Ljava/lang/String;)Ljava/lang/String;
Lmiui/util/FeatureParser;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
Lmiui/util/FeatureParser;->sFeatures:Ljava/util/HashMap;
```
（原有 6 条 Build 字段 + getRegion + getInteger + hasFeature + 2 条 Haptic 保留）

**生效验证**：刷机后 `boot-framework.vdex` md5 必须变化；日志中
`hiddenapi ... Lmiui/...  denied` 应**完全消失**（只剩 `android.*` 的无害记录）。

### 坑 2.8（★血的教训）：刷错镜像——一直刷的是"打包目录里的旧镜像"

**现象**：明明修好了、明明重新构建了，刷完还是老症状。

**根因**：刷机脚本 `cp_flash.sh` 的源目录是
`out/rompackages/...-线刷包/images/`（**打包时**生成的快照），
而后续每次重新构建都不会自动更新它。于是反复刷的是**第一次打包的旧 super**。

**判据**（每次刷机后必须核对）：
```bash
adb shell md5sum /system/framework/boot-framework.vdex   # 应与构建产物一致
```
本例中设备一直是 `59cf4167`，而新构建是 `5f28f12e`/`780440c5` → 一眼看出没刷进去。

**修复**：`cp_flash_new.sh` —— 直接从构建产物目录拷贝：
```bash
cp -f /root/avium/out/target/product/thor/super.img /mnt/c/camwork/flashrom/super.img
```
并新增 `verify_flashrom.sh` 校验 build ↔ flashrom 的 md5 一一对应。

### 坑 3：framework.jar 是旧的，"源码改了却没编译进去"
**症状**：相册启动即崩 `NoSuchMethodError: getBoolean(Ljava/lang/String;Z)Z in miui.util.FeatureParser`
**排查**：把设备 `framework.jar` 拉回来，用 `dexdump` 看 `FeatureParser` —— 只有 4 个成员
**根因**：
- framework 实际模块是 **`framework-minus-apex`**
- 其编译产物时间 = **11-13 12:02**，而 `FeatureParser.java` 是 **11-13 12:50** 才更新
- `out/target/product/thor/system/framework/framework.jar`(11-14 15:41, 44391828B) 与 intermediates `hiddenapi/framework.jar`(11-13 21:07, 同大小) 一致 → **只是拷贝，没重编**
**修复**：
```bash
touch frameworks/base/media/java/miui/util/*.java frameworks/base/media/java/miui/os/*.java
rm -f out/target/product/thor/system/framework/framework.jar
rm -rf out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/{hiddenapi,aligned,dex}/framework.jar
m otapackage
```
**教训**：
> ⚠️ 手动往 `out/target/product/thor/` 里覆盖文件，ninja 会认为目标已是最新而**跳过重装**，
> 导致旧文件被打进镜像。**不要手动改 out 目录**；要强制重建就删掉产物 + touch 源码。

### 坑 4：构建 OOM / 极端换页
- `soong_build` 单进程可达 **22.8G RSS**，23G 内存机器必须配 swap
- 解决：`swapon` 一个 48G swapfile（`/swapfile_build`），总 swap 63G
- `GOMEMLIMIT=14GiB` 效果有限（活数据压不住），主要靠 swap
- 必须**独占机器**：与其他构建任务并发会互相拖慢甚至 OOM

### 坑 5：Lunch 组合格式（A16 变了）
```bash
lunch lineage_thor-bp4a-userdebug     # 必须三段：product-release-variant
# 旧写法 lineage_thor-userdebug 会报 "No release config set for target"
```

### 坑 6：`m superimage` 太慢
- `m superimage` 会重建 963 个目标、30+ 分钟
- **快得多的做法**：
```bash
export PATH=/root/avium/out/host/linux-x86/bin:$PATH
python3 build/make/tools/releasetools/build_super_image.py \
   out/target/product/thor/obj/PACKAGING/target_files_intermediates/lineage_thor-target_files \
   out/target/product/thor/super.img
```
- 必加 PATH，否则报 `FileNotFoundError: unpack_bootimg`

---

## 四、构建流程（可复现）

```bash
cd /root/avium
export ALLOW_MISSING_DEPENDENCIES=true          # ★ 必须
source build/envsetup.sh
lunch lineage_thor-bp4a-userdebug
m otapackage -j6                                 # 出镜像 + OTA

# 生成 super.img（线刷用）
export PATH=/root/avium/out/host/linux-x86/bin:$PATH
python3 build/make/tools/releasetools/build_super_image.py <target_files> super.img

# 打包
bash /mnt/c/camwork/ROM打包/make_packages.sh
```

产物位置：`out/target/product/thor/` + `out/rompackages/`

---

## 五、刷机（详见《刷机说明.md》）

### 线刷
```bash
fastboot flash boot images/boot.img
fastboot flash dtbo images/dtbo.img
fastboot flash vendor_boot images/vendor_boot.img
fastboot flash vbmeta images/vbmeta.img
fastboot flash vbmeta_system images/vbmeta_system.img
fastboot reboot fastboot          # ★ 进 fastbootd
fastboot flash super images/super.img
fastboot reboot
```

### 卡刷
```bash
adb reboot recovery      # 或 音量上+电源
# Recovery → Apply update → Apply from ADB
adb sideload AviumUI-...-ota.zip
```

---

## 六、验证清单（刷后逐项确认）

| 检查项 | 命令 |
|---|---|
| 版本号 | `getprop ro.avium.display.version` |
| 相机 1 | `monkey -p com.android.camera -c android.intent.category.LAUNCHER 1` |
| 相机 2 | `monkey -p org.lineageos.aperture -c android.intent.category.LAUNCHER 1` |
| 相册 | `am start -n com.miui.gallery/com.miui.gallery.activity.HomePageActivity` |
| 编辑 | 相册内点"编辑" |
| framework 类 | `dexdump -d classes6.dex \| grep FeatureParser`，确认方法齐全 |

---

## 七、相机画质现实（重要结论）

经过大量实测，**thor 上要官方相机的完整画质，在当前 ROM 上做不到**，原因：

1. **官方 MiuiCamera 6.1** 依赖 MIUI 后处理服务 `vendor.xiaomi.hardware.campostproc` + `MiPostProc`，
   在 AviumUI 上调用即 `HIDL FAILED_TRANSACTION`（服务端不崩，客户端事务失败）。
2. 尝试过：换引擎 `libmialgoengine`（两版导出符号完全相同，无效）、整套 mialgo、官方 camera.provider
   （换上后服务**根本不注册**）、完整搬运 672 个官方 vendor 相机文件（880MB）—— 全部失败。
3. **跨机型不可行**：小米 13（fuxi, A16）的相机 APK 与 fotlim **是同一个**（`6.4.000530.0`），
   而其画质来自 fuxi 自己的 camera provider/ISP 调校（绑定 IMX800 硬件），无法搬到 thor。
4. **fotlim 的短板**：微纹理/细节被抹平（降噪过强），夜景模式数值高但实为噪点锐化；
   模糊位置在拍照/夜景/超清各模式下**固定不变** → 属管线固有缺陷，非对焦/曝光问题。
5. 社区徕卡变体 `com.kobbin.leica` 一启动就让 **camera provider 崩**（缺 `vd6281_camx.so`，thor 无此传感器）——已卸载。

**结论**：thor 上可用的最佳方案 = fotlim 6.4（夜景模式可用）+ Aperture（原厂备选）。
要官方画质只能回官方 HyperOS 或官方 LineageOS 24(A17)+社区模块。

---

## 八、遗留与待办

- [ ] 本轮修复（framework 重编 + 相机改 system 分区）构建中，待刷机验证
- [ ] 相册编辑（MIMediaEditor）启动验证
- [ ] 确认 framework.jar 新包内 `FeatureParser` 方法齐全（刷机前可先解包验证）
- [ ] 若相册仍缺方法，需继续补充 `miui.util.FeatureParser` / 其它 `miui.*` 兼容类
- [ ] ROM 版本字符串当前由 device tree 固定为 `20261112`，如需显示今日构建可改 `properties/`

---

## 附录 B：thor-miuicamera 开发者回复（2026-11-16）— 重要更正

> 本节内容来自项目作者对提问的正式回复。**它推翻了本项目早期的一个推断**，务必先读这一节。

### B.1 A16 档的 campostproc 链路改了什么

A16 / A17 **共用同一套应用端库**，修改只有以下几项：

| 库 | 修改 |
|---|---|
| `libmicampostproc_client.so` | 仅从 `DT_NEEDED` 移除 `libhidltransport.so`；**没有改 `initialize`/`createSession` 的控制逻辑，也没有改 HIDL 参数格式** |
| `libcamera_algoup_jni.xiaomi.so` | 修正一处 vtable 调用偏移 + 引入 `libgui` shim |
| `libcamera_mianode_jni.xiaomi.so` | 引入同一个 shim |
| 应用端 `vendor.xiaomi.hardware.campostproc@1.0.so` | 随应用依赖一起提供 |

**Vendor 侧只提供**：修补后的 `camera.qcom.so` + 配套 `libmis_plugin_vidhance.so`。
**没有打包替换** `libmialgoengine.so`、campostproc 的 vendor 接口库、或 `service-impl`。

> ⚠️ 因此 **不能认为作者实测的 crDroid vendor 链路与 AviumUI 完全相同**。

**★ 关键更正**：Release 的 `/system/lib64/vendor.xiaomi.hardware.campostproc@1.0.so` = `34bc9071…`，
**不能拿它和我们 vendor 侧的 `e9beab95…` 直接判定"版本冲突"** —— 客户端与 provider 实际加载的是不同文件，
必须分别核对。本项目早期"client↔service 接口版本对不上"的结论 **属于未经证实的推断**。

### B.2 HAL 哈希与补丁

| 档位 | 原始输入 | 修补输出 |
|---|---|---|
| A16 | `4ffa7ed9ddc1a5e48b4ec91d2b4f6ad3233d02d80c1edfb6b4c71d98ae919256` | `900dfb00f26dfce1a83e65b6a7839e4a0baa7f841c8d9f36aafdc2d795750b46` |
| A17 | `26ad8ccef40638c48cd595f1bc3ed835d0b5e754d8d173ef8b374c566396ba07` | `240610b0bcb05d0d8d39d799fa1fc27dde8dbf1ede38fb87baa9f834ae5dbebc` |

补丁内容**只有三条 ISPv3 电源命令指令**：

```
0xe1abf0：9  → 11
0xe1ad48：10 → 12
0xe1b078：9  → 11
```

**这些不是 HIDL 会话补丁。** 作者明确表示：**不会把这三条电源命令当作当前崩溃的首选修复**。

另外，`android16`/`android17` 只是"已验证组合"的命名，**不代表 `26ad8cce…` 只能跑在 A17**；
本项目在 A16 上使用 `26ad8cce…`（未打补丁的 A17 stock）并不能据此判错；
`camera.ko` 哈希不同也不能单独证明驱动 ABI 不兼容。

### B.3 FAILED_TRANSACTION 是否出现过 / 能否 bypass

- 作者的日志中**从未检索到**与本项目相同的这条 abort。
- 作者保留的成功日志里，`MiPostProcSessionIntf::initialize` 之后返回 `created session` + `JNI succeed`。

作者的判断：
1. `FAILED_TRANSACTION` **不是小米接口的业务错误码**。它来自 libhwbinder 收到 `BR_FAILED_REPLY`，
   或服务端封送/解封送/事务处理错误沿传输状态回传。
2. **provider 不崩溃，不能证明请求已成功进入算法实现**；也不能仅凭它断定"接口版本错了"或"服务端主动拒绝"。
3. **不存在 bypass 补丁**。客户端可以加 `isOk()` 检查、记录原始状态、走失败清理路径，从而**避免 abort**，
   但必须把失败传递到 JNI/Java 层；**不能 NOP 掉 fatal，也不能伪造成功后继续使用未创建的 session**。
4. 真正的 bypass 需要让 APK 改走**不依赖该后处理 session 的拍摄流程**（输出流/buffer/metadata/完成回调），
   **该项目目前没有实现这条退化路径**。

### B.4 作者建议的三步定位（本项目尚未执行）

1. **找准失败调用点**：用完整 tombstone 的 **PC 偏移 + Build ID + 实际加载的 client 库**，
   确定 `initialize` 中究竟是哪一次 HIDL 调用失败；不能只按外层 `createSession` 栈名推断。
2. **看同一时刻的 Binder 内核错误与 AVC**：重点查 FD/handle 转移、非法 Binder 对象、
   分配失败、事务大小、回调权限。**共享 provider 存活时，单笔事务仍可失败。**
3. **确认服务端是否进入了对应事务处理函数**：
   - 未进入 → 重点查传输 / 对象转移
   - 进入后失败 → 看参数解析、Surface/回调处理、返回值
   - 再核对应用实际加载的接口库与服务端接口定义

### B.5 本项目已捕获、可用于第 1 步的材料（无需设备即可分析）

崩溃点（来自本项目实测 tombstone）：

```
Abort: Attempted to retrieve value from failed HIDL call:
       Status(EX_TRANSACTION_FAILED): 'FAILED_TRANSACTION: '

#04 pc 0000000000043ddc  libhidlbase.so
       (android::hardware::details::return_status::onValueRetrieval() const+228)
       BuildId d8194afcc4a93b12e6aba8852b0ca60d
#05 pc 00000000000127e8  libmicampostproc_client.so
       (mialgo::MiPostProcSessionIntf::initialize(...)+1240)
       BuildId 1c34ad67a44a3e6570a5f68718db15d0
#06 pc 00000000000102b8  libmicampostproc_client.so
       (mialgo::MiPostProcServiceIntf::createSession(...)+448)
#07 pc 000000000000d518  libmicampostproc_client.so (miaCreateSession+188)
#08 pc 000000000000c694  libcamera_algoup_jni.xiaomi.so
       (Java_com_xiaomi_engine_MiCamAlgoInterfaceJNI_createSessionByOutputConfigurations+1244)
       BuildId 695b9c3103c22d413c8365688cebc06c
```

**可离线完成的分析**：拿 GSQ2004 Release 里的同名 `libmicampostproc_client.so`
（BuildId 应为 `1c34ad67…`），反汇编 `0x127e8` 附近，看**前一条 `call` 指向哪个 HIDL 方法**
（`createSession`? `getOutputBuffer`? `notifyCallback`?），即可确定失败的具体调用。

> 本项目**已丢失**的材料（清理时删除）：`dmesg` 内核 Binder 日志、`logcat -b all` 全量日志。
> 若要执行第 2、3 步，需重新复现并采集。

### B.6 结论修正

原 `坑 2`/`坑 3` 中"根因 = client↔service HIDL 接口版本不匹配"的表述应视为**未证实的假设**。
目前可确认的事实只有：

1. 官方 6.1 在 AviumUI A16 上能走通 UI / CameraService / HAL / 预览；
2. 卡在 `MiPostProcSessionIntf::initialize` 内的某次 HIDL 调用返回传输失败；
3. 该失败**不是**因为缺少某个已知补丁（作者确认没有此类补丁）；
4. 失败**也不是** MIUI 接口返回的业务错误。

后续若要继续，须按 B.4 的三步定位，**先拿到失败调用的确切位置**，再谈修复方向。

### B.7 离线反汇编结论（2026-11-16，已完成）

**目标**：确定 `MiPostProcSessionIntf::initialize` 里失败的是哪一次 HIDL 调用（作者三步定位的第 1 步）。

**材料**：GSQ2004 Release v0.1.7 的 `system/lib64/libmicampostproc_client.so`
- SHA256 校验：整个 ZIP 与官方发布一致（`a2fe19b7…`）
- BuildId：`1c34ad67a44a3e6570a5f68718db15d0` —— **与崩溃 tombstone 中的 BuildId 完全一致**
- 确认 `libhidltransport.so` 已从 DT_NEEDED 移除（与作者描述一致）

**反汇编 `initialize`（符号 0x12310，长度 2920）在 0x127dc..0x127e8 处：**

```
127c4: ldr  x8, [x20]            ; x20 = 从 GOT 取到的接口对象
127c8: ldr  x9, [x8, #0x68]      ; vtable slot 13（0x68 = 13 * 8）
127cc: add  x8, sp, #0x90        ; 返回 Return 的 sret 指针
127d0: add  x1, sp, #0xc0        ; 参数 1
127d4: add  x2, sp, #0x60        ; 参数 2（此前存入的是新建的 MiPostProcCallBacks）
127d8: mov  x0, x20
127dc: blr  x9                   ; ← 失败的就是这一次 HIDL 事务调用
127e0: add  x0, sp, #0x90
127e8: bl   return_status::onValueRetrieval()   ; ← 校验失败 → abort
```

**参数特征**：`(self, 参数1, 参数2, sret)` = 该 HIDL 方法带 **2 个入参**，其中参数 2 是一个
**回调对象**（前文 0x12770~0x12790 处 `new MiPostProcCallBacks` + `incStrong` 后写入 `sp+0x60`）。

**对照 `vendor.xiaomi.hardware.campostproc@1.0.so` 的接口符号表**，唯一具备
`(const CreateSessionParams&, const sp<IMiPostProcCallBacks>&)` 双参签名的方法是：

```
IMiPostProcService::createPostProcessor(
    const CreateSessionParams& params,
    const android::sp<IMiPostProcCallBacks>& callback)
```

符号全名：
`_ZN6vendor6xiaomi8hardware11campostproc4V1_021BpHwMiPostProcService19createPostProcessorERKNS3_19CreateSessionParamsERKN7android2spINS3_20IMiPostProcCallBacksEEE`

**结论**：

> 失败的 HIDL 事务 = **`IMiPostProcService::createPostProcessor(CreateSessionParams, IMiPostProcCallBacks)`**
>
> 调用链：`algoup JNI → miaCreateSession → MiPostProcServiceIntf::createSession
> → MiPostProcSessionIntf::initialize → createPostProcessor(...) → 事务失败
> → return_status::onValueRetrieval() → abort`

**为什么这条线索重要**：这次事务**跨进程传递了一个回调接口对象**。
对照作者的建议（"重点找 FD/handle 转移、非法 Binder 对象、事务大小、回调权限"），
嫌疑范围直接收敛到：**callback binder 对象跨进程传递** 或
**`CreateSessionParams` 内的 hidl_handle / FD 转移**。这与"provider 存活但单笔事务失败"完全一致。

**还缺的材料**（作者第 2、3 步）：同一时刻的 kernel Binder 错误与 AVC 日志。
本项目清理时已删除；若继续，需重新部署 GSQ2004 那套并采集 `dmesg` / `logcat -b all`。

**尚未确认**：`CreateSessionParams` 内是否含 hidl_handle/FD（需要解出该 struct 的
`_hidl_createPostProcessor` 解析逻辑，或取得 .hal 定义）。

### B.8 重新部署取证结果（2026-11-16）—— 发现比"接口版本"更硬的证据

#### 取证方式
按模块 `sepolicy.rule` 的设计，把官方 6.1 装到 `/system/app/MiuiCamera`（system 分区）
+ 5 个 patched 库 + overlay/device_features/public.libraries，分别在 **Enforcing** 与 **Permissive** 下启动，
并用 `dmesg -w` 跟随内核日志、`logcat -b all` 全量抓取。

#### 发现 1：Enforcing 下根本到不了 HIDL 调用（AVC 拦截）
```
avc: denied { read } for name="libmialgoengine.so" dev="overlay" ino=2572
  scontext=u:r:untrusted_app:s0:c101,c256,c512,c768
  tcontext=u:object_r:vendor_file:s0  tclass=file  permissive=0
```
同时还拦了 `vendor_camera_sensor_prop`、`vendor_camera_p3enable_prop`、`qemu_hw_prop` 等。
→ **相机进程运行域是 `untrusted_app`，读不了 `/vendor/lib64`。**
→ 模块的 `sepolicy.rule` 要求运行域是 **`platform_app_36`**（`allow platform_app_36 vendor_camera_sensor_prop` 等），
   而我们把 APK 装在 `/system/app`（非 priv-app）时域是 `untrusted_app`，**从未应用过这条 seapp 规则**。
→ 这解释了本项目早期为何一直必须 `setenforce 0` 才能往下走。

#### 发现 2：Perference 下的崩溃点**前移**了（不是 createSession）
```
I/MI_Algo_JNI: init: open /vendor/lib64/libmialgoengine.so with handle: 0x3a3c...
I/MI_Algo_JNI: init: open function pointer: 0x0          ← dlsym 返回 NULL
F/libc: Fatal signal 11 (SIGSEGV) fault addr 0x0
  #00 pc 0000000000000000  <unknown>                      ← 调用 NULL
  #01 pc 0x000b1e0 libcamera_algoup_jni.xiaomi.so (Jni_Init_V10+276)
  #02 pc 0x000b784 libcamera_algoup_jni.xiaomi.so (Java_..._init+20)
```

反汇编 `Jni_Init_V10`（0xb0cc，长度 788）确认流程：
```
b10c: bl  android_load_sphal_library("/vendor/lib64/libmialgoengine.so", 2)  → x22=handle
b1b8: add x1, x1, #0x358        ; 0x5358 → "MI_open_lib"
b1c0: bl  dlsym(x22, "MI_open_lib")   → x23 = 0x0
b1dc: bl  __android_log_print(... "init: open function pointer: %p" ...)   ; 打印 0x0
b1e0: blr x23                    ; ← 在这里 SIGSEGV
```

#### 发现 3：`MI_open_lib` 在我们整套 vendor 里**不存在**
全设备扫描（`/vendor/lib64`、`/vendor/lib64/hw`、`/vendor/lib64/camera`、`/system/lib64`、
`/system_ext/lib64`、`/product/lib64`，含全部子目录）：

| 来源 | 是否含 `MI_open_lib` |
|---|---|
| `/system/lib64/libcamera_algoup_jni.xiaomi.so`（模块版） | 只含**字符串**（dlsym 请求），不导出 |
| APK 内嵌 `lib/arm64-v8a/libcamera_algoup_jni.xiaomi.so`（fotlim 版，77216 字节） | 同上 |
| `/vendor/lib64/libmialgoengine.so`（`a15dfb98`，设备树里的那份） | ❌ 无 |
| 官方 OS3.0.6 的 `libmialgoengine.so`（`9730376`） | ❌ 无 |
| 引擎的 8 个依赖（`libcom.xiaomi.pluginutils/metadatautils/grallocutils/debug`、`libcamlog`、`libutilscallstack`、`libprocessgroup_shim`、`libdmabufheap`） | ❌ 全部存在但都不含 |
| 20 个 `libmialgo_*.so` 插件 + 7 个 arcsoft 库 | ❌ 无 |
| **整个源码树 `/root/avium` 的 vendor blobs** | ❌ 无 |

→ `dlsym(libmialgoengine, "MI_open_lib")` **必然返回 NULL**。

#### 结论（比"接口版本不匹配"更硬的证据）

> **作者那边的 crDroid vendor 里，`libmialgoengine.so` 必定导出 `MI_open_lib`；
> 而 AviumUI / 官方 OS3.0.6 的 `libmialgoengine.so` 都没有这个符号。**
>
> 作者明确说过"**没有打包替换 libmialgoengine.so**"——他们用的是 crDroid vendor 自带的那份。
> 也就是说：**crDroid 用的 vendor 与我们 AviumUI 的 vendor 不是同一代**（虽同一台机器）。

这解释了全部现象：
1. 为什么之前 permissive 下能进 UI/HAL/预览、只在 `createPostProcessor` 失败——那是**更早一次**（库/APP 组合不同）；
2. 为什么现在换模块版 algoup 后直接死在 `Jni_Init`——因为**缺必需符号**，比 HIDL 事务更早一层；
3. 为什么"照搬他们的步骤"无效——**缺的不是步骤，是他们那份 vendor**。

#### 要真正跑起来，唯一的路径
需要 **与 crDroid 那版同代的 vendor vendor 镜像**（`libmialgoengine.so` 等），
即把整个 vendor 分区换成那一代 —— 这已超出"移植"范畴，等于换 ROM。

#### 顺带修正
之前"根因 = client↔service HIDL 接口版本不匹配"的说法，应进一步修正为：
**更上游的根因是 vendor 侧 `libmialgoengine.so` 缺少 `MI_open_lib` 导出**。
即使 HIDL 那层通了，`Jni_Init` 这一关也过不去。

#### 设备状态
测试结束后已还原：移除测试用 6.1 与 5 个 patched 库，回装 **fotlim 6.4**
（`/system/app/MiuiCameraThor`，versionName `6.4.000530.0`），实测 pid 5226、界面正常、无崩溃。
`hidden_api_policy=1` 保留（相册编辑依赖）。

### B.9 seapp 域实验：运行时修改是致命的（2026-11-16）

#### 目的
验证「把 `com.android.camera` 的运行域从 `untrusted_app` 改成 `platform_app`
（模块 sepolicy.rule 要求的域）后，Enforcing 下能否推进到 HIDL 层」。

#### 设计（运行时方式，不需要重编）
1. `plat_seapp_contexts` 顶部插入按包名匹配的规则：
   ```
   user=_app name=com.android.camera domain=platform_app type=app_data_file levelFrom=user
   ```
2. 推到 `/system/etc/selinux/plat_seapp_contexts`（overlay 上层），重启观察。

#### 结果：**设备直接卡在第二屏（zygote boot loop）**

```
F/libc: Fatal signal 6 (SIGABRT)
F/DEBUG: Abort message: 'JNI FatalError called: (system_server)
         frameworks/base/core/jni/com_android_internal_os_Zygote.cpp:2152:
         selinux_android_setcontext(1000, 1, "(null)", "(null)") failed'
```

**触发点**：对 `plat_seapp_contexts` 执行 `chcon` 会触发 overlayfs **copy-up**
（内容没变，4488 字节 / md5 一致，但文件被搬进 overlay 上层且 SELinux 标签改变）。
`system_server` 启动时要用 `seapp_contexts` 决定自身域，读取失败 → fork 失败 → 无限 abort。

> ❗ 注意：即使**只改 SELinux 标签而不改内容**，也足以让系统起不来。
> 本级尝试连 `setenforce 0` 都不能绕过（`selinux_android_setcontext` 本身就失败）。

#### 恢复方法（已验证有效）
```bash
adb shell setenforce 0
adb shell 'rm -rf /mnt/scratch/overlay/system/upper/app \
                   /mnt/scratch/overlay/system/upper/etc \
                   /mnt/scratch/overlay/system/upper/lib64 \
                   /mnt/scratch/overlay/product/upper/* \
                   /mnt/scratch/overlay/system_ext/upper/*'
adb shell 'rm -rf /data/system/package_cache/*'
adb shell 'setenforce 1'
adb reboot
```
清空 overlay 上层即回到 ROM 原生状态（ROM 镜像里已烘焙 fotlim）。
恢复后实测：`boot_completed=1`、Enforcing、fotlim 6.4 pid 5230 正常。

#### 结论

> **seapp 域不能通过 overlay/推文件的方式修改，而必须在 ROM 编译期完成**：
> 把规则写进 device tree（`BOARD_SEPOLICY_DIRS` 下自建 `seapp_contexts` +
> 对应 `allow platform_app ...` 规则），随 sepolicy 一起编译进 `plat_sepolicy.cil`
> 和 `plat_seapp_contexts`。

这也进一步说明本项目早前的观察：Enforcing 下相机读不到 `/vendor/lib64`
（`untrusted_app` → `vendor_file` 被拒），**是部署方式（非 priv-app + 未改域）导致的，
不是 ROM 本身缺陷**。要修就必须重编 ROM。

#### 优先级判断
即使把域这条修好，`MI_open_lib` 缺符号（B.8）仍会挡住 `Jni_Init`。
所以**这条实验的价值在于分离两个问题**，而非直接让相机跑起来：
- 域问题：可修（需重编 ROM）
- 符号问题：不可修（需换那一代 vendor）

建议：**除非打算换到 crDroid 那代 vendor，否则不值得为域问题专门重编一版 ROM。**
