# 小米相机（MiuiCamera 6.x）KernelSU 模块适配 —— 交接文档

> **用途**：本会话（ROM 编译 / App 内置 / ROM 魔改）将「通过 KSU 模块适配小米相机」这条线**转交其它会话**继续。
> 本文是截至 2026-11-17 的完整现状、已解决/未解决问题、构建部署流程与红线。
> **接手方**：请先通读本文件 + 同目录 `CREDITS.md`，再动手。
> 模块工程源码：当前在 `C:\Users\LinOcean\Documents\deepseek-harness\rom\avium-miuicamera\`（Windows 侧；WSL 内无独立目录）。

---

## 0. TL;DR 当前状态

- **自建 KSU 模块可用**：模块 id `avium_miuicamera_thor18`，版本 `1.2.5-avium`。
- 真机实测：相机**能启动、能预览、能拍照**，出片 **3000×4000 / 约 2.7–2.9 MB**，画质正常（细节/色彩/曝光 OK，8K 录像也验证过）。
- 当前 payload 用的是 **「按本机调校过的」那套库 + 开发者已绕过 CTA 的 APK（`5e1816cf…`）**，**不是官方原签名 APK**。
- **未完成**：让**官方原签名 APK（`dfb0c5fe…`）**也能原样跑起来 —— 卡在 CTA（见 §9）。

---

## 1. 目标与背景

- 目标：把**小米官方相机 MiuiCamera 6.x** 装到自建 ROM **AviumUI-16.2.2（thor / Android 16 / LineageOS 22 基底）** 上正常使用。
- 早期路线「把相机内置进 ROM 分区」已判定为死胡同（见 `MIUI_COMPAT_NOTES.md` 与 `BUILD_PITFALLS.md` §五）。
- 现路线：**不改 ROM 分区，用 KernelSU 模块在开机时 overlay 到 `/system`**。好处：可热插拔、可回滚、不动 ROM 本体。
- 关键要求（用户）：**模块脚本/策略由我们（AviumUI）自己写**；payload 用到的第三方文件必须在模块描述/`CREDITS.md` 里**完整署名**。

---

## 2. 环境事实（务必对齐）

| 项 | 值 |
|---|---|
| 机型 | Xiaomi 12S Ultra（thor，2203121C，SM8475 / Snapdragon 8+ Gen 1） |
| ROM | AviumUI-16.2.2（Android 16，LineageOS 22 基底），build `BP4A.251205.006` |
| ROM 属性 | `userdebug`，`ro.debuggable=0`，SELinux **Enforcing** |
| Kernel | GKI `5.10.269-gki-g490755fcc6cc-dirty`，**KernelSU 32730** 已编译进内核 |
| KSU 用户态 | `ksud 3.3.1 (uapi 5)` |
| **必需 metamodule** | **meta-overlayfs v1.3.1**（sha256 `279d85a6…`）。KSU 3.x 没有它，`/system` 的模块内容**根本不会被挂载**。 |
| 模块落地位置 | meta-overlayfs 的 **2GB ext4 镜像**：`/data/adb/modules/meta-overlayfs/mnt/<模块id>/` |
| 分区格式 | system / product / system_ext 均为 **EROFS**（不是 ext4 → 7-Zip 读不了，需设备端 loop 挂载提取） |

---

## 3. 总体架构

```
KernelSU (in-kernel)
   └─ meta-overlayfs (metamodule, 提供 ext4 镜像 + overlay 挂载)
        └─ avium_miuicamera_thor18 (我们的模块)
             ├─ module.prop / customize.sh / prepare.sh / post-fs-data.sh / service.sh / action.sh
             ├─ sepolicy.rule / system.prop
             └─ payload/  → 开机 overlay 到 /system/{priv-app,lib64,…}
```

- payload 目录结构复刻「模块内相对 `/system` 的路径」，例：`payload/system/priv-app/MiuiCamera/MiuiCamera.apk`、`payload/system/lib64/...`。
- `post-fs-data.sh` / `service.sh` 负责：开机自动 `pm grant` 相机所需运行时权限、按 inode 变化判断并重启相关 provider（避免升级后权限残留问题）。

---

## 4. 模块工程结构（`rom\avium-miuicamera\`）

| 文件 | 作用 |
|---|---|
| `module.prop` | 模块元数据。**保存必须无 UTF-8 BOM**（见 §6 坑）。 |
| `customize.sh` | 安装期脚本（校验环境、落位权限等） |
| `prepare.sh` | 安装前准备 |
| `post-fs-data.sh` | 开机早期挂载后动作 |
| `service.sh` | 开机 `pm grant` 自动授权 + 按 inode 重启 provider |
| `action.sh` | 模块动作（KSU 管理器里点按触发） |
| `sepolicy.rule` | 运行期 SELinux 规则（注意：域规则仍需编译期，见 §6/§9） |
| `system.prop` | 追加属性（含 `ro.control_privapp_permissions=log` 等） |
| `build.ps1` | Windows 打包脚本（打 zip；支持 payload 顶层 `system/ product/ system_ext/ vendor/`） |
| `payload/` | 实际 overlay 的系统文件（见 §5） |
| `README.md` / `STATUS.md` / `CREDITS.md` | 说明 / 状态 / 第三方署名 |
| `system\etc\permissions\privapp-permissions-avium-miuicamera.xml` | **由官方 APK `aapt dump permissions` 全量生成的 68 条 privapp 权限白名单** |
| `system\etc\sysconfig\avium-miuicamera-hiddenapi.xml` | hiddenapi 放行 |
| `system\etc\public.libraries-xiaomi.txt` | 公开库声明 |
| `system\etc\default-permissions\avium-miuicamera.xml` | 默认授权 |

---

## 5. payload 组成（★必须是「配套的一套」）

> **最核心的教训：HAL / JNI / campostproc / overlay 四者必须来自同一套调校版本，混搭必翻车。**

| 文件（相对 `payload/system`） | 来源 / 说明 |
|---|---|
| `priv-app/MiuiCamera/MiuiCamera.apk` | 当前 = 开发者 CTA-绕过版 `5e1816cf…`；官方原签名见 §8 |
| `lib64/libcamera_algoup_jni.xiaomi.so` | 官方 system_ext；开发者适配（含 vtable 修正 + libgui shim） |
| `lib64/libcamera_mianode_jni.xiaomi.so` | 同上适配 |
| `lib64/libgui_shim_miuicamera.so` | 开发者 2.3KB 符号桩（补 `BnProducerListener::onBufferDetached` 等 A16 缺失符号） |
| `lib64/libmicampostproc_client.so` | 官方；开发者做了「移除 DT_NEEDED libhidltransport」适配 |
| `lib64/vendor.xiaomi.hardware.campostproc@1.0.so` | 官方（应用端接口库） |
| `lib64/libhidltransport.so` + `libhwbinder.so` | 官方**空壳桩（0 导出）**，仅为满足 dynstr 依赖 |
| `vendor/lib64/hw/camera.qcom.so` | **HAL = `240610B0…`（由本机原厂 `26ad8cce…` 打的补丁）★画质关键** |
| `vendor/lib64/libmis_plugin_vidhance.so` | 官方 vendor，随调校套分发 |
| `product/etc/device_features/thor.xml` | 官方 device_features |
| `product/overlay/MiuiCameraOverlayLeicaed/…apk` | 徕卡 Leica overlay（`0429E7DC…`） |
| `system_ext/framework/miui-cameraopt.jar` | **官方 225KB 原件**（修 `CameraOptManager` ClassNotFound） |

**配套哈希（这套是验证过画质最好的）**
- `camera.qcom.so` = `240610B0BCB0…`
- `libmicampostproc_client.so` = `17D442B52F9D…`
- `vendor.xiaomi.hardware.campostproc@1.0.so` = `34BC907192B1…`
- `MiuiCameraOverlayLeicaed.apk` = `0429E7DC3225…`

---

## 6. 已解决的问题（含坑与修法）

1. **模块根本不挂载** → KSU 3.x 必须装 **meta-overlayfs**（metamodule）。没装 = 白忙。
2. **官方 APK 装上进不去 / bootloop** → 它申请 **68 个权限**（`INTERACT_ACROSS_USERS_FULL`、`MANAGE_EXTERNAL_STORAGE`、`INJECT_EVENTS`…），白名单只有 9 条 → PMS 强制校验失败。
   **修**：用 `aapt dump permissions` 全量导出生成 68 条 allowlist，并加 `ro.control_privapp_permissions=log` 兜底。修后官方 APK 能正常开机。
3. **`libcamera_algoup_jni` 缺符号 `BnProducerListener::onBufferDetached`（A16 已移除）** → 用 `libgui_shim_miuicamera.so` 桩。
   手法：把官方 algoup 的 `DT_NEEDED` 里 `android.hidl.token@1.0-utils.so` 字符串**等长改写**为 `libgui_shim_miuicamera.so`（先确认原符号未被实际使用，再改 dynstr）。
4. **`open libmicampostproc_client.so failed: "libhidltransport.so" not found`** → 把官方 `libhidltransport.so` + `libhwbinder.so`（都 0 导出空壳）放进 `/system/lib64`。
   ⚠️ **反例（血坑）**：把 `libhidlbase.so` / `libhidlmemory.so` 也塞进 `/system/lib64` 会**搞坏 cameraserver（开机卡首屏/卡挂）**。只放那两个空壳，`libhidlbase` 用系统自带的（721488 字节）。
5. **meta-overlayfs 2GB 镜像被历次安装塞满** → 每个模块 ~200MB，10 个版本就满；表现为「新模块内容拷不进去 / 模块目录缺 system」。
   **对策**：安装前 `rm -rf /data/adb/modules/meta-overlayfs/mnt/<旧id>`；**换 payload 内容务必换新模块 id**。
6. **`module.prop` 被 PowerShell `Set-Content -Encoding utf8` 写出 BOM** → 模块 id 变成带不可见字符的 `﻿avium_miuicamera_thor16`，旧目录清不掉、两个模块同时挂载。
   **修**：`[System.IO.File]::WriteAllText(path, text, (New-Object System.Text.UTF8Encoding($false)))`（**无 BOM**）。
7. **`ClassNotFoundException: com.miui.cameraopt.CameraOptManager`** → 之前用 165 字节 stub jar；换成**官方 225KB `miui-cameraopt.jar`**，并把 `system_ext/framework` 支持加进 `build.ps1`。
8. **画质发白/糊 / 出片 93KB** → 见 §8 的 A/B，本质是 HAL/JNI 不配套。

---

## 7. 构建 / 部署 / 验证流程（Windows，无需 WSL）

```powershell
# 1) 打包
& C:\Users\LinOcean\Documents\deepseek-harness\rom\avium-miuicamera\build.ps1

# 2) 清理 metamodule 旧镜像目录（改过 payload 时必做）
adb shell "rm -rf /data/adb/modules/meta-overlayfs/mnt/<上一个id>"

# 3) 推送 + 安装
adb push <新zip> /data/local/tmp/avium_cam.zip
adb shell "/data/adb/ksud module install /data/local/tmp/avium_cam.zip"

# 4) 重启并等待开机
adb reboot ; # 等 sys.boot_completed=1

# 5) 验证
adb shell "sha256sum /system/priv-app/MiuiCamera/MiuiCamera.apk"   # 应等于 payload APK 哈希
adb shell "am start -n com.android.camera/.Camera"
adb shell "input keyevent 27 ; ls -lt /sdcard/DCIM/Camera/IMG_*.jpg | head"
```

- **换 payload 内容 = 换新模块 id**（否则镜像残留旧文件）。
- 部署目录见 §2；meta-overlayfs 镜像满了会静默失败。

---

## 8. 画质结论（4 组 A/B 实测）

| 组 | HAL | JNI | 结果 |
|---|---|---|---|
| v4 | `26ad8cce`（本机原厂） | 官方 A15 | 能开，但**算法引擎不加载**，出片 1080×1440 发白糊 |
| v5 | `900dfb00`（crDroid） | 官方 A15（自打 shim） | 引擎起来了，但**照片 93KB**、有蓝色残影 |
| v6 | `900dfb00` | 开发者 JNI | ~2.9MB，正常 |
| **v7/v8** | **`240610B0`**（本机 26ad8cce 打的补丁） | 开发者 JNI | **3000×4000 ~3MB，画质最好 ✅** |

**结论**：不是相机的锅，是 **HAL / JNI / campostproc / overlay 必须配套**。最终采用 v7/v8 这套。

---

## 9. 遗留问题：官方原签名 APK 的 CTA（接手重点）

**现象**：官方原签名 APK（`dfb0c5fe…`）装在系统里，一启动就走 CTA 流程 → 没有 `com.miui.securitycenter` → `setupCamera: skipped`、黑屏/退出。

**已查清的事实**
- CTA 触发：`com.xiaomi.camera.cta.requester.a.b()` 发 `startActivityForResult(miui.intent.action.SYSTEM_PERMISSION_DECLARE, pkg=com.miui.securitycenter)`。
- CTA 类在 **classes2.dex**（`com/xiaomi/camera/cta/**`；整包 baksmali 容易漏）。
- 自建了 `com.miui.securitycenter` **桩 Activity**（`rom\stub\`，aapt 生成真实二进制清单 + smali + 自签，`CN=AviumUI Stub`）：装上后**不再 ActivityNotFound**，Intent 能解析到 StubActivity。
- **但**：相机真正看的是 **`content://com.miui.securitycenter.remoteprovider`** 这个 **ContentProvider**（LBE 安全中心），我们只有 Activity、没有 Provider → `mIsNewCTAShowing` 恒 true → `setupCamera: skipped`。
- 且装桩后，**连原本可用的 dev APK 也会被这个 Intent 拦**（它同样发该 Intent，之前是抛异常被吞掉）。→ 已**卸载桩**，恢复可用。

**已定位的 Provider 调用协议**（`y2/a.smali`，MiviInfoRepository，供接手参考）
```
Uri   = content://com.miui.securitycenter.remoteprovider
method= "callPreference"                          // ContentProviderClient.call("callPreference", "GET", bundle)
其中 arg = "GET"；Bundle keys：
   "type"    : int   => 2
   "key"     : String=> "pref_gesture_effect_apps_list"   // 还会查 pref_miviinfo_for_hal_version_eco / _dynamic 等
   "default" : String=> ""
返回 Bundle 里按同名 key 取 String：bundle.getString("pref_gesture_effect_apps_list","")
```
> 注意：上面这个 provider 是 **MiviInfo（gesture/dynamicInfo）** 的路径，**与 CTA 门控不是同一处**。CTA 的 `mIsNewCTAShowing` 还需另行精确定位（`Camera.smali` 里 `setupCamera: skipped` 附近门控，`out_c1b\com\android\camera\Camera.smali`）。接手请先厘清「CTA 状态到底从哪个 key/provider/文件读取」。

**已试过但**没通**的 APK 补丁**（`rom\cta\`）：
- classes2 让 CTA 不启动（`cta/requester/a.b` 提前 return）→ 不崩，但黑屏。
- classes 里 `setupCamera` 门控 boolean 翻转 → 未命中真正跳过点，仍 `setupCamera: skipped`。
- 两者叠加 → 仍跳过。

**建议的接手方向（二选一）**
1. **实现 `com.miui.securitycenter.remoteprovider` 的 `ContentProvider`**：`StubProvider extends ContentProvider` 覆写 `call(method, arg, extras)`，对 `callPreference` 返回 `Bundle(getString(key)=默认/合理值)`；同时补齐 CTA 状态 key。→ 支持**官方原签名 APK 原样使用**（无需改 APK 签名）。
2. 继续**精确反编译定位 CTA 真门控**并做最小字节码补丁（需保持官方签名则要自签，会改签名，用户可能不接受）。

> 接手前请先确认用户到底是要「官方原签名」还是「能用就行」——目前 dev APK 完全能用；要不要为「原签名」继续投入由用户定。

---

## 10. 关键哈希 / 文件

| 名称 | sha256（前缀） | 备注 |
|---|---|---|
| dev APK（当前在用） | `5e1816cf…` | 179,112,210B，签名 `CN=Thor Camera Development` |
| 官方原签名 APK | `dfb0c5feb4944503c35afe79b791a73773756e706782ac82d24018e7ee80004a` | 179,661,008B，签名 `CN=MIUI,O=Xiaomi` |
| HAL（画质最佳） | `240610B0…` | |
| campostproc client | `17D442B52F9D…` | |
| campostproc@1.0 | `34BC907192B1…` | |
| Leica overlay | `0429E7DC3225…` | |
| meta-overlayfs | `279d85a6…` | metamodule |

**官方提取件**：`rom\official\`（`off2\prod\MiuiCamera.apk` 官方、`devapk\MiuiCamera.apk` 可用版、`devlibs\`、`hidl_off\`、`miui-cameraopt.jar`）
**CTA 工作区**：`rom\cta\`（classes.dex / classes2.dex 及补丁、`MiuiCamera_ctafix*.apk`）
**桩 APK**：`rom\stub\`（`signed\stub-aligned-aligned-signed.apk`、`stub.keystore`，口令 `android`，别名 `aviumstub`）

---

## 11. 工具链（全部在 Windows）

- Java 21：`C:\Users\LinOcean\AppData\Roaming\.minecraft\runtime\java-runtime-delta\bin\java.exe`
- adb / fastboot：`C:\Users\LinOcean\Downloads\adb-fastboot\`
- build-tools（aapt/aapt2/zipalign）、`android.jar`、smali/baksmali 3.0.10、uber-apk-signer：`rom\tools\`
- Python（打包/解稀疏）：`C:\Users\LinOcean\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe`
- **本线此前不允许用 WSL**；全部 Windows 工具完成。

---

## 12. 红线 / 注意事项

- ❗ **不要删**：`rom\` 整个子树（尤其 `avium-miuicamera\`、`official\`、ROM 镜像、`D:\thorrom\partitions\` 7.65G 官方分区）。
- ❗ `module.prop` 必须**无 BOM**。
- ❗ 换 payload 内容 **必须换新模块 id + 清 `meta-overlayfs/mnt/` 旧目录**。
- ❗ 别把 `libhidlbase.so`/`libhidlmemory.so` 放进 `/system/lib64`（会坏 cameraserver）。
- ❗ 每次都在真机验证；报实情。
- 第三方文件务必在 `CREDITS.md` + `module.prop` 描述里**署名完整**（用户明确要求）。

---

## 13. 下一步建议（给接手方）

1. 先按 §7 把当前 `thor18` 复现一遍，确认相机/拍照 OK（基线）。
2. 与用户确认「是否一定要官方原签名 APK」：
   - 要 → 按 §9 方向 1 实现 `remoteprovider`（`ContentProvider.call`）+ 定位 CTA 真门控 key。
   - 不要 → 收尾：整理 `.bak`、补 README、稳定版发布即可。
3. 取景蓝条残影（右下竖条）——疑与 `libgui_shim` 桩有关，可对比开发者原模块是否复现。

---

*本交接文档由 ROM 编译会话整理，模块开发请在新会话继续。*
