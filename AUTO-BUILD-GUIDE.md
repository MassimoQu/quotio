# Quotio 自动构建与同步指南

## 🎯 目标

建立一个"无感"的持续集成流水线，实现：
- ✅ 每6小时自动检测上游更新
- ✅ 自动合并 nguyenphutrong/quotio 的更改
- ✅ 自动构建包含新功能的 Quotio
- ✅ 自动发布到 GitHub Releases

## 📁 流水线文件

已创建两个 GitHub Actions 工作流：

### 1. `build.yml` - 手动构建
- 地址：https://github.com/MassimoQu/quotio/actions/workflows/build.yml
- 点击 "Run workflow" 即可手动触发构建

### 2. `auto-sync.yml` - 自动同步（推荐）
- **自动触发**：每6小时检查一次上游
- **检测到更新**：自动合并并构建
- **发布到 Releases**：自动创建下载链接

## 🚀 立即使用

### 方式一：手动触发构建（快速）

1. 访问：https://github.com/MassimoQu/quotio/actions/workflows/build.yml
2. 点击 **"Run workflow"**
3. 等待构建完成（约5-10分钟）
4. 下载构建产物：
   - **Quotio-app**: 直接的 .app 文件
   - **Quotio-dmg**: 安装包

### 方式二：等待自动同步（推荐）

当原仓库（nguyenphutrong/quotio）发布新版本时：
1. 系统自动检测到更新（每6小时）
2. 自动合并代码
3. 自动构建并发布
4. 你只需要下载使用即可

## 📊 下载地址

构建完成后，访问：
- **GitHub Releases**: https://github.com/MassimoQu/quotio/releases
- **Actions Artifacts**: https://github.com/MassimoQu/quotio/actions

## 🔧 技术细节

### 自动同步流程

```
原仓库更新 (nguyenphutrong/quotio)
    ↓ 每6小时检测
检测到新版本
    ↓
自动合并代码到本仓库
    ↓
macOS 构建 (Apple Silicon)
    ↓
创建 DMG 和 ZIP 包
    ↓
发布到 GitHub Releases ✅
```

### 分支策略

- **master**: 稳定版本
- **feature/smart-model-selection-and-usage-tracking**: 新功能分支
- **feature/github-actions-build**: CI/CD 分支

## 💡 使用建议

### 定期检查更新

每周访问一次 GitHub Releases，下载最新版本：
https://github.com/MassimoQu/quotio/releases

### 安装新版本

```bash
# 1. 下载文件到桌面
cd ~/Downloads

# 2. 解压
unzip Quotio-v*.app.zip

# 3. 移动到 Applications（会提示替换，选择替换）
mv Quotio.app /Applications/
```

### 保留旧版本

首次安装时，系统会自动将旧版本备份到：
```
~/Desktop/Quotio_old_YYYYMMDD_HHMMSS.app
```

## 🔒 注意事项

1. **首次打开**：需要右键点击 → "打开"
2. **权限**：如果提示权限问题，在终端执行：
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/Quotio.app
   ```

## 📝 下一步计划

1. **提交 PR 到原仓库**（长期方案）
   - 将功能合并到 nguyenphutrong/quotio
   - 获得官方支持

2. **Webhook 触发**（可选）
   - 原仓库发布时立即触发构建
   - 更快获取更新

## ❓ 常见问题

### Q: 构建失败了怎么办？
A: 检查 Actions 日志，可能是：
- XcodeGen 未安装
- Xcode 版本问题
- 代码冲突

### Q: 如何手动强制构建？
A: 访问 build.yml 页面，点击 "Run workflow" 并勾选 "force_rebuild"

### Q: 能自动安装到我的电脑吗？
A: 目前需要手动下载安装。后续可考虑添加自动下载脚本。

## 📞 获取帮助

- **Issues**: https://github.com/MassimoQu/quotio/issues
- **Actions**: https://github.com/MassimoQu/quotio/actions

---

**最后更新**: 2026-01-28
**版本**: 1.0
