# MAA「月满」主题兼容补丁

为《明日方舟》「月满」主界面增加 MAA 导航识别支持。

这是独立的非官方补丁。使用 AI 辅助编写，基于用户提供的截图制作按钮模板；未包含 MAA 程序或账号配置。

## 当前状态

- 针对 Windows、MAA v6.20.1、简体中文游戏、16:9 画面制作。
- 新增终端、基建、公开招募、采购中心、任务、好友、仓库、干员、干员寻访九个导航入口。
- 已通过两张参考图的离线匹配、13 张历史截图的误匹配检查，以及本机 MaaCore 资源加载验证。
- **尚未验证真实模拟器中的完整点击流程，请先小范围试用。**测试记录见 [验证结果.json](验证结果.json)。

## 安装

1. 下载本仓库：点击绿色 **Code → Download ZIP**，然后解压。
2. 完全退出 MAA，包括托盘中的程序。
3. 找到 MAA 的安装目录，也就是能看到 `MAA.exe` 的文件夹。
4. 将解压后的整个补丁文件夹放进该目录。保留补丁内部的目录结构。
5. 双击补丁文件夹中的 `恢复月满补丁.cmd`。
6. 双击 `启动MAA（月满兼容）.cmd` 启动 MAA。

示例目录结构：

```text
你的 MAA 安装目录/
├─ MAA.exe
├─ resource/
├─ cache/
└─ MAA-YueMan-main/            ← 整个补丁文件夹
   ├─ Apply-MoonTheme.ps1
   ├─ manifest.json
   ├─ 恢复月满补丁.cmd
   ├─ 启动MAA（月满兼容）.cmd
   └─ templates/
```

公开分享版会根据文件夹位置查找 `MAA.exe`，没有绑定作者电脑的安装路径。文件夹可以改名，但其中的脚本、manifest 和 templates 必须保持相对位置不变。

也可以将补丁保存在其他位置，并在 Windows PowerShell 中指定安装目录：

```powershell
.\Apply-MoonTheme.ps1 -MaaDir 'E:\Apps\MAA'
```

## 更新与恢复

补丁会新增以下文件：

```text
cache/resource/tasks/LocalYueMan20261028_custom.json
cache/resource/template/LocalYueMan20261028/*.png
```

没有修改官方 `resource`、MAA 程序、账号设置、任务设置或自动更新设置。

MAA v6.20.1 会先加载官方资源，再加载缓存资源。补丁利用后加载的资源层，扩展九个入口的候选列表。当前正常官方资源更新流程通常会保留这些文件；清空 cache、重装或未来改变资源结构仍可能导致失效。

建议使用兼容启动器：它会在启动前根据当前官方候选列表检查、重建补丁，补回缺失的模板。出现结构变化或重名冲突时会报错，不能保证兼容未来全部版本。

如果更新后识别失效，先完全退出 MAA，再双击 `恢复月满补丁.cmd`。请另外保存一份下载的压缩包，方便重新安装。

## 检查和卸载

- `检查补丁.cmd`：检查九张图片及十八条任务定义。
- `卸载月满补丁.cmd`：完全退出 MAA 后运行，只移除此补丁新增的识别规则和模板。

## 原理

从截图中裁剪按钮上的固定文字和图案，作为识别参考图；MAA 将它们与当前游戏画面进行模板匹配，成功后点击按钮内指定区域，再执行原有任务流程。模板避开理智数值与基建通知数字。

`manifest.json` 记录九个入口的模板、识别区域、阈值与点击区域。坐标基于 MAA 内部 1280×720 画面。好友模板阈值为 0.72，其余为 0.75。

不要把生成的覆盖文件放进官方 `resource/tasks`，同一资源层的任务重名会造成冲突。

## 问题反馈

反馈时请提供 MAA 版本、游戏语言、画面分辨率、失败入口以及经过遮挡处理的截图。不要上传账号配置、完整安装目录或未经检查的日志。

## 相关项目与素材

- [MAA 官方仓库](https://github.com/MaaAssistantArknights/MaaAssistantArknights)
- [MAA 任务流程协议](https://docs.maa.plus/zh-cn/protocol/task-schema.html)
- [v6.20.1 资源加载顺序](https://github.com/MaaAssistantArknights/MaaAssistantArknights/blob/v6.20.1/src/MaaWpfGui/Main/AsstProxy.cs)

模板图片取自《明日方舟》游戏画面，相关游戏素材归其权利方所有。本仓库不是 MAA 或《明日方舟》的官方项目。
