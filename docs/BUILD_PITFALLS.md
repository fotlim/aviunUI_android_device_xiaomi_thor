# 小米 12S Ultra（thor）AviumUI ROM 编译踩坑记录

> **机型**：Xiaomi 12S Ultra（thor，2203121C，SM8475）
> **ROM**：AviumUI-16.2.2（Android 16 / LineageOS 22 基底，`BP4A.251205.006`）
> **构建树**：WSL2 Ubuntu 22.04，`/root/avium`
> **最后整理**：2026-11-17

---

## 来源标注（本文数据从哪来）

本文是对以下三方材料**交叉整理**的「踩坑清单」，不是拍脑袋：

1. **已归档会话「小米12SU编译1」**（用户消息 504 条，记录从「评估编译硬件条件 → TWRP/OrangeFox 适配 → 类原生编译 → 相机/相册整合」的完整过程）。
2. 本地真实构建日志：`/root/avium/build_2cam_gallery.log`、`build_fix2.log`、`build_hidden.log`、`build_romint.log`、`build_superimg.log`（均以 `#### build completed successfully` 正常收尾）。
3. 设备树内 `MIUI_COMPAT_NOTES.md`（694 行完整技术记录，含附录 B 开发者回复与离线反汇编）。

> 标注约定：**【环境】【构建】【fw】【镜像】【整合】【TWRP】** 分别对应问题的所属阶段。

---

## 一、【环境】构建环境相关

### 坑 1：内存不足 / 极端换页（OOM）
- **症状**：`soong_build` 单进程 RSS 可冲到 **22.8G**，23G 内存的机器直接 OOM 或卡死。
- **修复**：`swapon` 一个 **48G swapfile**（如 `/swapfile_build`），总 swap ≈ 63G；`GOMEMLIMIT=14GiB` 效果有限（活数据压不住），主要靠 swap 兜底。
- **必须独占**：与其他构建任务并发会互相拖慢甚至 OOM。归档中用户后来直接「换内存条」解决根本内存压力。
- **归档佐证**：多次出现「编译完了吗，怎么内存占用降低了」「好像之前看到你把内存吃满了」。

### 坑 2：断电 / 降频 / 任务不可续
- **症状**：归档中构建机 23 点断电；断电后 CPU 降频到 ~1.2GHz，只能再撑 ~25 分钟。
- **对策**：把编译拆成**分段任务**；WSL 重启不丢已编译产物（增量可续），只需 `source build/envsetup.sh && lunch … && m …` 重跑。

### 坑 3：构建输出别放 C 盘页面文件盘
- 归档要求：编译产物放 **F: 那块 SATA 固态**，C 盘只做页面文件；E 盘是游戏盘不要动。

---

## 二、【构建】构建系统 / Soong / Make

### 坑 4：Lunch 组合格式（Android 16 变了）
```bash
lunch lineage_thor-bp4a-userdebug      # 必须三段：product-release-variant
# 旧写法 lineage_thor-userdebug → 报 "No release config set for target"
```

### 坑 5：`ALLOW_MISSING_DEPENDENCIES=true` 必须开
- 缺了会因个别可选依赖缺失直接中断。构建流程固定为：
```bash
cd /root/avium
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch lineage_thor-bp4a-userdebug
m otapackage -j6
```

### 坑 6：`m superimage` 太慢 → 用 `build_super_image.py`
- `m superimage` 会重建 963 个目标、30+ 分钟。
- 快得多的做法：
```bash
export PATH=/root/avium/out/host/linux-x86/bin:$PATH    # 必加，否则 FileNotFoundError: unpack_bootimg
python3 build/make/tools/releasetools/build_super_image.py \
   out/target/product/thor/obj/PACKAGING/target_files_intermediates/lineage_thor-target_files \
   out/target/product/thor/super.img
```

### 坑 7：`res/` 目录里的备份文件让 aapt2 报错
- **症状**：`error: invalid file path '.../res/values/config.xml.bak_xxx'`
- **原因**：aapt2 会把 `res/` 下**所有文件**当资源编译。
- **修复**：备份文件移出 `res/`，统一放 `_backups/`。

### 坑 8：presigned APK 含压缩 JNI 库被 soong 拒绝
- **症状**：`MiuiGallery.apk: Contains compressed JNI libraries`
- **原因**：Android 15+ 要求 presigned prebuilt 的 `.so` 必须 STORED（未压缩），小米 APK 是 Deflate。
- **修复**：patch `build/soong/scripts/check_prebuilt_presigned_apk.py`，`has_preprocessed_issues(args, fail=True)` → `fail=False`（原文件备份 `.bak_avium`）。实测压缩 `.so` 的 APK 在 product 分区运行完全正常。

### 坑 9：ELF 预编译文件经 PRODUCT_COPY_FILES 拷贝被拦
- **症状**：相册/编辑的 `.so` 要装到 `<app>/lib/arm64`，`PRODUCT_COPY_FILES` 拷 ELF 报错。
- **修复**：`BoardConfig.mk` 加 `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true`。

### 坑 10：手动覆盖 `out/` 目录 → ninja 认为已最新而跳过重装（★★）
- **症状**：源码改了、也 `m` 了，刷进去却还是旧行为。
- **原因**：手动往 `out/target/product/thor/…` 覆盖文件，ninja 看时间戳认为目标已最新 → 不重装。
- **修复/铁律**：**不要手改 out 目录**。要强制重建就删产物 + `touch` 源码：
```bash
touch frameworks/base/media/java/miui/util/*.java frameworks/base/media/java/miui/os/*.java
rm -f  out/target/product/thor/system/framework/framework.jar
rm -rf out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/{hiddenapi,aligned,dex}/framework.jar
m otapackage
```

---

## 三、【fw】framework / hiddenapi

### 坑 11：framework.jar 是旧的，「源码改了没编进去」
- **症状**：`NoSuchMethodError: getBoolean(Ljava/lang/String;Z)Z in miui.util.FeatureParser`。
- **排查**：framework 实际模块是 **`framework-minus-apex`**；其产物时间早于源码更新时间 → 只是拷贝没重编。用 `dexdump` 看设备上的 `framework.jar`，`FeatureParser` 只有 4 个成员。
- **修复**：见坑 10 的「删产物 + touch 源码 + `m otapackage`」。
- **验证**：刷机后 `boot-framework.vdex` 的 md5 **必须变化**。

### 坑 12：Hidden API 限制 —— 相册崩溃的真正原因（★★★最坑）
- **症状**：相册启动即崩 `NoSuchMethodError`，但方法在 dex 里「明明存在」，root 反射也能调。
- **真正日志**：`hiddenapi: Accessing hidden method Lmiui/util/FeatureParser;->getBoolean(...) (domain=platform, api=blocked) from MiuiGallery.apk!classes2.dex … using linking: denied`
- **根因**：`miui.util.FeatureParser` 在 framework.jar 属 **platform domain**，方法被标 **blocked**；相册是 app 域（targetSdk 35）→ `linking: denied` → 抛 `NoSuchMethodError`（不是方法不存在，是**禁止访问**）。
- **快速验证（无需重编）**：`adb shell settings put global hidden_api_policy 1`（关限制）→ 相册**立刻能开**。但这是运行时开关，**不是最终方案**。
- **正式修复**：把方法加入 `frameworks/base/boot/hiddenapi/hiddenapi-unsupported.txt`（unsupported=允许，仅告警）。
- **易错点**：之前有人**只补了** `getInteger`、`hasFeature` 两条，漏了相册实际调用的 `getBoolean(String,boolean)` 等 → 照样崩。**「之前成功过现在又坏」的真正差异就是白名单没补全。**

### 坑 13：`Build.IS_TABLET` 等字段也被拦（坑 12 的延续）
- **症状**：`hiddenapi: Accessing hidden field Lmiui/os/Build;->IS_TABLET:Z … linking: denied` → `NoSuchFieldError`。
- **系统排查法**（避免反复试错）：反汇编 gallery dex，抓所有对 `Lmiui/*` 的引用。注意 `dexdump` 成员分隔是 **`;.`** 不是 `;->`：
```bash
dexdump -d classes*.dex | grep -oE 'Lmiui/[A-Za-z0-9_/$]+;\.[A-Za-z0-9_$<>]+(:[A-Za-z0-9_/$;[]+|\([A-Za-z0-9_/$;[]*\)[A-Za-z0-9_/$;[]+)'
```
- **最终白名单**（`hiddenapi-unsupported.txt` 追加 13 条）：`Build.IS_TABLET/DEVICE/PRODUCT/FINGERPRINT` + `FeatureParser.getBoolean×2/getInt×2/getLong×2/getString×2/sFeatures`（另保留原有 Build 字段、getRegion、getInteger、hasFeature、Haptic×2）。

---

## 四、【镜像】镜像与刷机

### 坑 14：一直刷的是「打包目录里的旧镜像」（★★血的教训）
- **症状**：明明修好、重新构建了，刷完还是老症状。
- **原因**：刷机脚本源目录是 `out/rompackages/…-线刷包/images/`（**打包时快照**），后续重新构建**不会自动更新它** → 反复刷第一次打包的旧 super。
- **判据**：每次刷完核对 `adb shell md5sum /system/framework/boot-framework.vdex` 是否等于新构建产物。
- **修复**：`cp_flash_new.sh` 直接从构建产物拷贝 `out/target/product/thor/super.img`；并加 `verify_flashrom.sh` 校验 build ↔ flashrom md5 一一对应。

### 坑 15：`/odm` 只有 1.6MB，塞 `precompiled_sepolicy` 差点砖（★★）
- **症状/教训**：`/odm` 分区仅 1.6MB，放不下 1.5MB 的 precompiled_sepolicy，**截断 → 差点变砖**。
- **结论**：删掉它、让 init **运行时编译** sepolicy 反而最稳。归档原话：「关键教训：/odm 只有 1.6 MB…之前那次截断差点砖。删掉它让 init 运行时编译反而最稳。」

### 坑 16：用 overlay/推文件改 `plat_seapp_contexts` 是**致命**的
- **症状**：运行时改 seapp 域规则 → 设备**卡第二屏 zygote 无限重启**：`selinux_android_setcontext(1000,…) failed`。
- **原因**：对 `plat_seapp_contexts` 执行 `chcon` 触发 overlayfs **copy-up**，即使**内容不变、只改 SELinux 标签**，也足以让 system_server 起不来（连 `setenforce 0` 都救不了）。
- **结论**：seapp 域规则**必须在 ROM 编译期**写进 device tree（`BOARD_SEPOLICY_DIRS` 下自建 `seapp_contexts` + 对应 `allow` 规则），随 sepolicy 编进 `plat_sepolicy.cil`。运行时改不可行。
- **恢复方法（已验证）**：清空 overlay 上层 + `rm -rf /data/system/package_cache/*` + `setenforce 1` + reboot。

### 坑 17：fastbootd 判定 & 刷 super
- 刷 super 需先进 **fastbootd**：`fastboot reboot fastboot`；`fastboot devices` 显示的仍是 "fastboot"，要用 `fastboot getvar is-userspace` 看是否 `yes` 确认。
- 顺序：`boot / dtbo / vendor_boot / vbmeta / vbmeta_system` → 进 fastbootd → `super` → reboot。

---

## 五、【整合】功能整合（相册 / 相机 / 音效）

### 坑 18：相机放 product 分区崩溃（libbase 找不到）
- **症状**：`dlopen failed: library "libbase.so" not found … in namespace product-clns-11`。
- **根因**：product 应用的 linker namespace 是 `/product/lib64:/system/product/lib64`，**不含 `/system/lib64`**，APK 内嵌 `libcamera_algoup_jni.xiaomi.so` 找不到系统库。
- **修复**：相机改放 **system 分区**（`/system/app`，`Android.bp` 删除 `product_specific: true`）→ 获得 system namespace。

### 坑 19：相册/编辑 APK `extractNativeLibs=true` 但预装不解压
- **症状**：点开图片 `UnsatisfiedLinkError: BindCPUCoreUtils.bindCPU`（`libbindcore.so` 加载失败）。
- **修复**：把 `lib/arm64-v8a` 的 `.so` 抽出，用 `PRODUCT_COPY_FILES` 显式装到 `<app>/lib/arm64/`（本次共 24+40 个 .so，见 `device.mk` 中 `[miui_gallery libs]` 段）。

### 坑 20：MiSound（A15 Java 应用）进 priv-app → 卡第二屏
- **症状**：开机卡第二屏。
- **结论**：**不要预装 `MiSound.apk`**（A15 的 Java 应用不兼容）；只搬它的 native 库（`libmisoundfx` 等，实测 A16 能 dlopen）。

### 坑 21：徕卡风格可切换，但滤镜崩 / 切换无实际效果
- **现象**：徕卡风格开关能切，但滤镜功能崩、且照片没明显风格变化。
- **结论**：风格/滤镜依赖 MIUI 后处理链路，非纯开关；这是 ROM 内置相机方案的固有限制（详见 `MIUI_COMPAT_NOTES.md` §七）。要真画质须换官方 HyperOS 或官方 LineageOS + 同代 vendor。

---

## 六、【TWRP】Recovery 适配线（早期，来自归档「小米12SU编译1」）

> 这条线是正式编 ROM 之前独立做的，结论可复用。

- **目标**：一份能适配 Android 14→17、且能解密 data 的第三方 rec（TWRP / OrangeFox）。
- **卡「第一屏」循环**：多版都卡一屏 / 不断重启；A14 基线的 14.1 分支不适配较新系统，**切到 android-12.1 基线**（OrangeFox R12.0）后方向对了。
- **data 解密失败**：`Decrypt进程错误结束：6 解压数据失败`、`无法挂载 /data/media/0/.foxs`。
  - **技巧（来自酷安 ref 编译者）**：把 recovery 里 `prop.default` 的 `version.release` / `version.release_or_codename` 改成所需版本（如 15）再试。
- **MTP 与解密挂钩**：data 解不了就只能走 `/sdcard` 挂载路线；MTP 能挂 data 但读写异常。
- **结论**：先出一个「功能完整的 rec」再谈类原生；对照不同机型的成功 rec（如 it ishtar 的 A17 rec）有助排错。
- 最终 TWRP 树落库：`fotlim/TWRP-device_xiaomi_sm8475_thor`（OrangeFox R12.0 / 12.1 base，含 /data 解密、壁纸引擎）。

---

## 七、快速自检清单（每次出包/刷机后）

| 检查 | 命令 / 判据 |
|---|---|
| 版本号 | `getprop ro.avium.display.version` |
| framework 是否真更新 | `adb shell md5sum /system/framework/boot-framework.vdex` = 构建产物 |
| 是否刷的旧镜像 | build ↔ flashrom 的 super.md5 一致（`verify_flashrom.sh`） |
| hiddenapi 是否清干净 | `logcat` 里 `hiddenapi … Lmiui/… denied` 应**完全消失** |
| 相机 | `am start -n com.android.camera/.Camera`，再拍照看尺寸/大小 |
| 相册 | `am start -n com.miui.gallery/com.miui.gallery.activity.HomePageActivity` |
| 编辑 | 相册内点「编辑」 |
| 是否卡第二屏 | 多半是 seapp overlay 被改过 / MiSound 被预装 |

---

## 附录：构建流程（可复现）

```bash
cd /root/avium
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch lineage_thor-bp4a-userdebug
m otapackage -j6

# 生成 super.img（线刷用）
export PATH=/root/avium/out/host/linux-x86/bin:$PATH
python3 build/make/tools/releasetools/build_super_image.py <target_files> super.img

# 打包（线刷/卡刷）
bash /root/avium/ROM打包/make_packages.sh
```
产物：`out/target/product/thor/` + `out/rompackages/`

---

*本文与 `MIUI_COMPAT_NOTES.md`（完整技术长文）配套使用；后者含更细的附录 B（thor-miuicamera 开发者回复、离线反汇编结论、seapp 域实验等）。*
