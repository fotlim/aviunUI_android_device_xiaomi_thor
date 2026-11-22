# AviumUI thor 刷机说明（线刷 / 卡刷）

> 机型：Xiaomi 12S Ultra（thor，2203121C）
> ROM：AviumUI-16.2.2-thor-20261115-Unofficial-Vanilla（Android 16）
> 内含：**两个相机**（fotlim MiuiCamera 6.4 + 原厂 Lineage Aperture）、**小米相册 + 相册编辑**（MiuiGallery 4.3.1.18 + MiuiMediaEditor 2.4.0.5.2，含 miui_compat 兼容层与 hiddenapi 白名单）
>
> ✅ 本包已在真机验证：开机正常、两个相机可启动、**小米相册可正常显示照片**、编辑已预装。

---

## 0. 前置条件

- 手机**已解锁 Bootloader**（BL）。
- 电脑安装好 **adb / fastboot**（platform-tools）。
- Windows 需装好 Xiaomi USB 驱动；`fastboot devices` 能识别。
- **务必备份**：线刷会覆盖系统分区；如需干净升级，先备份照片/数据（清数据会抹掉 /data）。

---

## 一、线刷（Fastboot）

### 1. 进入 fastboot
- 关机后按住 **音量下 + 电源** 进入 fastboot；或：
  ```
  adb reboot bootloader
  ```
- 确认连接：
  ```
  fastboot devices
  ```

### 2. 一键刷入（任选）
- **Windows**：双击 `flash-all.bat`。
- **Linux/Mac**：
  ```
  chmod +x flash-all.sh
  ./flash-all.sh
  ```

### 3. 手动分步命令（等价）
```bash
# 物理分区（bootloader 下）
fastboot flash boot        images/boot.img
fastboot flash dtbo        images/dtbo.img
fastboot flash vendor_boot images/vendor_boot.img
fastboot flash vbmeta      images/vbmeta.img
fastboot flash vbmeta_system images/vbmeta_system.img

# 动态分区（super）→ 必须先进入 fastbootd
fastboot reboot fastboot
fastboot flash super images/super.img

# 重启
fastboot reboot
```

> 说明：thor 是动态分区（super）机型，`super.img` 里含 system / product / system_ext / vendor。
> `fastboot reboot fastboot` 后屏幕会显示 fastbootd 界面，属正常。

---

## 二、卡刷（Recovery / Sideload）

### 方式 A：Lineage Recovery（推荐）
1. 进入 Recovery：
   ```
   adb reboot recovery
   ```
   或关机后按 **音量上 + 电源** 进入。
2. Recovery 界面选择 **Apply update → Apply from ADB**。
3. 电脑执行：
   ```
   adb sideload AviumUI-16.2.2-thor-20261114-ota.zip
   ```
4. 刷完选择 **Reboot system now**。

### 方式 B：TWRP
- TWRP 里直接 **Install** 选择 OTA zip 刷入，然后重启。

> 卡刷包为完整 OTA（约 2.3G），首次刷建议在 Recovery 里先 **Format Data**（清数据）再刷，避免旧数据冲突。

---

## 三、刷后检查

1. 开机后确认系统版本：设置 → 关于手机 → 版本号 `AviumUI-16.2.2-thor-20261114`。
2. **相机**：桌面应有两个相机图标
   - **相机**（fotlim MiuiCamera 6.4，MIUI 风格）
   - **Camera / Aperture**（Lineage 原厂）
3. **相册**：打开「相册」应为小米相册（MiuiGallery 4.3.1.18），支持「编辑」调用小米相册编辑。
4. 如相册首次打开提示权限，按提示授予即可（已预置常用权限）。

---

## 四、常见问题

| 现象 | 处理 |
|---|---|
| `fastboot devices` 无设备 | 换数据线/装驱动；`adb kill-server && adb start-server` |
| `fastboot flash super` 报分区不存在 | 确认已 `fastboot reboot fastboot` 进入 fastbootd |
| **`super` 刷写中途失败（AdbWriteEndpointSync failed / 信号灯超时 121 / 设备不响应）** | **USB 链路不稳**：拔插数据线（等 5 秒）或换 USB 口/换原装线，然后重试；可先 `fastboot erase super` 再刷 |
| 卡刷 `adb sideload` 卡住 | 换 USB 口；确认 Recovery 已选 "Apply from ADB" |
| 开机卡 logo | 回 fastboot 重刷 boot/vbmeta；或清 data 重试 |
| 相册/相机异常 | **先核对是否刷进了最新镜像**：`adb shell md5sum /system/framework/boot-framework.vdex` 与构建产物一致才算刷对 |

> ⚠️ **重要**：如果自己重新构建过 ROM，**务必从构建产物目录**
> `out/target/product/thor/{super,boot,dtbo,vendor_boot,vbmeta,vbmeta_system}.img`
> 拷贝镜像去刷，**不要用打包目录里的旧快照**，否则会一直刷到旧系统。
> 建议刷完用 `boot-framework.vdex` 的 md5 校验。

---

## 五、回滚

- 保留一份旧版 `AviumUI-16.2.2-thor-20261112` 的线刷包或卡刷包，出问题可刷回。
- 线刷回滚：同「线刷」流程刷旧版镜像即可。

---

*本说明随包提供，命令与实际镜像文件名以包内为准。*
