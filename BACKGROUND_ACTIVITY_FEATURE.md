# 后台任务完成提示功能

## 功能概述

当后台标签页中的任务完成时，系统会自动高亮该标签页的文字，用金黄色提示用户后台有任务完成。

## 工作原理

### 1. 按键追踪（press_anything）

- 每个 VTE 终端都有一个 `press_anything` 标志位
- 当用户在终端中按下任何键时，该标志位被设置为 `true`
- 这表示用户在该终端中执行了命令或操作

### 2. 标题变化检测（window_title_changed）

当 VTE 终端触发 `termprop_changed` 信号（xterm.title）时：

1. **更新标签文字**：无论是否是后台标签，都会更新标签栏的文字内容
2. **检查是否高亮**：
   - 如果是**后台标签**（非当前活跃标签）
   - 且 `press_anything` 为 `true`
   - 则发出 `background_activity` 信号，触发标签高亮

### 3. 标签高亮显示

- **高亮颜色**：金黄色 `#FFD700` (rgba(1.0, 0.843, 0.0, 1.0))
- **只高亮后台标签**：当前活跃的标签不会被高亮
- **视觉效果**：标签文字从灰色变为醒目的金黄色

### 4. 取消高亮

当用户切换到产生活动的标签时：
1. 自动清除该标签的高亮状态
2. 将该标签的 `press_anything` 重置为 `false`
3. 标签文字恢复为正常的蓝色（活跃标签）

## 使用场景示例

### 场景 1：编译任务
```bash
# 在标签 1 中启动长时间编译
make -j8

# 切换到标签 2 继续工作
# ... 用户在标签 2 中工作 ...

# 当编译完成时，标签 1 的文字变为金黄色
# 提示用户编译任务已完成
```

### 场景 2：SSH 连接
```bash
# 在标签 1 中 SSH 到远程服务器
ssh user@remote

# 切换到标签 2
# ... 用户在本地工作 ...

# 当 SSH 连接建立成功（或失败）时
# 标签 1 文字变为金黄色提示用户
```

### 场景 3：下载任务
```bash
# 在标签 1 中下载大文件
wget https://example.com/large-file.iso

# 切换到标签 2 处理其他任务
# ... 用户继续工作 ...

# 下载完成时，标签 1 文字变为金黄色
```

## 技术实现

### TerminalTab.vala

1. **添加 press_anything 哈希表**
   ```vala
   private HashTable<Vte.Terminal, bool> press_anything;
   ```

2. **监听按键事件**
   ```vala
   var key_controller = new Gtk.EventControllerKey();
   key_controller.key_pressed.connect((keyval, keycode, state) => {
       press_anything.set(terminal, true);
       return false;
   });
   ```

3. **处理标题变化**
   ```vala
   terminal.termprop_changed.connect((prop_name) => {
       if (terminal != focused_terminal && press_anything.get(terminal)) {
           background_activity();  // 发出高亮信号
       }
   });
   ```

4. **重置标志位**
   ```vala
   focus_controller.enter.connect(() => {
       press_anything.set(terminal, false);
   });
   ```

### TabBar.vala

1. **添加 highlighted 字段**
   ```vala
   private class TabInfo {
       public bool highlighted;
   }
   ```

2. **修改绘制逻辑**
   ```vala
   if (info.highlighted) {
       cr.set_source_rgba(1.0, 0.843, 0.0, 1.0);  // 金黄色
   }
   ```

### Window.vala

1. **连接信号**
   ```vala
   tab.background_activity.connect(() => {
       if (index != tab_bar.get_active_index()) {
           tab_bar.set_tab_highlighted(index, true);
       }
   });
   ```

2. **切换标签时清除高亮**
   ```vala
   private void on_tab_selected(int index) {
       tab_bar.clear_tab_highlight(index);
   }
   ```

## 颜色说明

- **金黄色高亮**：`#FFD700` - 醒目但不刺眼
- **活跃标签**：`#2CA7F8` - 蓝色
- **普通标签**：`rgba(0.7, 0.7, 0.7, 1.0)` - 灰色

## 注意事项

1. 只有在用户按下按键后（`press_anything = true`），标题变化才会触发高亮
2. 活跃标签永远不会被高亮（因为用户正在查看它）
3. 切换到高亮的标签会自动清除高亮状态
4. 每次获得焦点时，`press_anything` 会被重置为 `false`
