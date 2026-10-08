# 我的個人 Dotfiles 與 AI 設定

**把我希望長期保留的開發環境設定與共用 AI 指引，整理成一份可版本控管、方便檢視的來源。**

我建立這個 repository，讓換電腦時能還原自己的設定，也讓不同 AI client 使用的共用指引維持一致。這裡使用 chezmoi 管理我選擇納入版本控制的設定：我在這裡修改來源檔、檢查產生的設定，再套用到家目錄。

這是我實際使用並公開分享的個人設定，方便其他開發者了解這些取捨、挑選需要的部分自行調整。它不是通用預設：應用程式自行管理的狀態與憑證留在本機，機器專屬的 profile 選擇不會提交。

## 為什麼建立這個 repository

電腦和工具一換，開發環境設定就容易慢慢走樣。AI 指引也可能因為同一條規則被複製到多個 client 專屬檔案而不一致。這個 repository 讓想長期保留的設定有一個方便檢視的來源，同時保留各應用程式原本的操作方式。

這套設計想解決幾個實際問題：

- **重現設定：** 透過 bootstrap 和 chezmoi 來源檔，在新電腦上還原常用設定。
- **維持 AI 指引一致：** 共用規則與 skill 保留一份來源，減少複製到不同 client 設定後逐漸走樣。
- **清楚界定管理範圍：** template 說明 repository 管理哪些設定，並盡可能保留應用程式自行維護的值。
- **讓變更容易檢查：** Git 讓來源檔的修改清楚可見，`chezmoi diff` 則能在套用前預覽這台機器的目標設定。

## 專案如何運作

```mermaid
flowchart LR
    subgraph source["版本控制中的設定來源"]
        dotfiles["想長期保留的 dotfiles"]
        shared["共用 AI 規則與 skill"]
        adapters["精簡的 client 專屬 wrapper"]
    end
    profile["機器本機的 ai_context<br/>（不提交到 Git）"] --> render["chezmoi 組合設定"]
    dotfiles --> render
    shared --> render
    adapters --> render
    render --> ai["AI client 原生設定位置<br/>Claude Code · Codex · GitHub Copilot"]
    ai --> local["由 client 管理的狀態<br/>session · 憑證 · runtime"]
    render --> settings["Shell · Git · editor · terminal<br/>以及其他長期保留的設定"]
```

Git 追蹤撰寫好的設定與共用指引。chezmoi 會把這些來源和機器本機的 profile 組合起來，再產生到各工具讀取的位置。共用規則與 skill 保留一份來源，再透過精簡 wrapper 接到各 client 支援的位置；Claude Code、Codex 和 GitHub Copilot 的 session、憑證與 runtime 狀態仍由各工具管理。

## 值得先看的流程

| 想做什麼 | 從哪裡開始 | 它會怎麼做 |
| --- | --- | --- |
| 在不同 client 共用 AI 指引 | [AI 設定支援對照](./docs/customization-support.md) | 共用規則與 skill 會送到 Claude Code、Codex 和 GitHub Copilot 支援的設定位置；client 專屬行為只套用在支援它的 client。 |
| 把需求帶到可檢查的變更 | [`run-task-end-to-end`](./home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md) | 接受自然語言任務、相關材料，以及 `phase=plan|execute`、`base`、`target`、`branch`、`workspace=current|worktree` 和 `verification=agent|balanced|user` 等選填提示。plan 或 review 只回報發現與建議，不會修改檔案。execute 會確認實際工作目錄、執行可用的自動化檢查，並在適用時執行 runtime 或瀏覽器測試；verification 選項會決定使用者檢查與手動測試關卡，通過後才依 profile 慣例建立 commit。有指定 target 或明確要求發布時，流程會重新確認 target；若 target 已移動，會先停下來等 merge 或 rebase 的明確決定，再重跑受影響的檢查，接著 push 並建立 pull request／merge request（PR/MR）。 |
| 把工作交給另一個 AI session | [`task-handoff`](./home/.chezmoitemplates/skills/task-handoff/SKILL.md) | 產生可貼到另一個 session 的摘要，包含 checkout、變更、決策、檢查結果、阻礙、材料和下一步。接手者的驗證狀態會標為 pending，並附上檢查清單；只有接手者能確認內容是否仍正確。 |
| 在另一台電腦還原挑選過的設定 | [`home/`](./home/) | 用 chezmoi 管理想長期保留的設定，套用前可先用 `chezmoi diff` 檢查。 |

例如，呼叫 `run-task-end-to-end` 時可以附上任務和已知選項：`根據附上的快捷鍵規格實作功能；phase=execute base=main branch=feat/keyboard-shortcuts target=main workspace=worktree verification=balanced`。`base` 是任務起點（branch 或 commit），`branch` 是任務分支，`target` 是 PR/MR 目標分支並會要求發布。如果有提供 `target` 但未提供 `base`，除非 repository 規則另有要求，流程也會用 `target` 當作起點。未提供 `branch` 時，repository 規則會決定要推導分支名稱或詢問必要資訊。使用 `phase=plan` 可只取得分析結果與建議的下一步，不會修改檔案。

任務流程大致如下：

```mermaid
flowchart TB
    request["任務與材料"] --> hints["選填 prompt 提示：<br/>phase=plan|execute<br/>base=branch-or-commit（任務起點）<br/>branch=task-branch（任務分支）<br/>target=destination-branch（PR/MR 目標；要求發布）<br/>workspace=current|worktree<br/>verification=agent|balanced|user"]
    hints --> resolve["依 repository 規則處理；<br/>詢問尚缺的必要資訊"]
    resolve --> phase{"這是 plan 或 review 請求嗎？"}
    phase -->|是| plan["回報發現與下一步；<br/>不修改檔案"]
    phase -->|執行| workspace["使用選定的 client workspace；<br/>從 base 建立任務 branch；<br/>確認 Git 根目錄、branch 和起始 commit"]
    workspace --> work["實作並執行可用的<br/>自動化、runtime 與瀏覽器檢查"]
    work --> gate{"選定的驗證方式需要<br/>使用者檢查或手動測試嗎？"}
    gate -->|需要| review["檢查結果並完成<br/>必要的使用者檢查"]
    gate -->|不需要| delivery{"有指定 target 或明確要求發布嗎？"}
    review --> delivery
    delivery -->|沒有| local["依目前 profile 慣例<br/>在本機建立 commit"]
    delivery -->|有| publish["重新 fetch 並確認 target；若已移動，<br/>先停下來等 merge 或 rebase 的明確決定，<br/>重跑受影響的檢查，再 commit、push 並建立 PR/MR"]
```

## 日常使用的小便利與防護

這些設計讓我更容易掌握 AI session 狀態，也能確認變更是否真的通過檢查：

| 功能 | 用途 | 查看實作 |
| --- | --- | --- |
| Claude Code 狀態列（Bash 與 PowerShell） | 狀態列會依終端機寬度調整版面，顯示模型與推理強度、可選的 session 名稱、專案路徑與 Git 狀態、context 使用量，以及資料可用時的 5 小時或 7 天用量百分比與重設時間。 | [Bash](./home/dot_claude/claude-session-statusline.sh)、[PowerShell](./home/dot_claude/claude-session-statusline.ps1) 和[設定來源](./home/.chezmoitemplates/claude/settings-durable.json)。 |
| 桌面通知（Windows 與 macOS） | Claude Code 等待使用者回應，或 agent、subagent 完成時會提醒；Codex session 結束時也會提醒。Windows 和 macOS 各有一支通知腳本，兩個 client 也各自設定 hook。 | [Windows 腳本](./home/dot_local/share/show-agent-notification.ps1)、[macOS 腳本](./home/dot_local/share/show-agent-notification-macos.sh)、[Claude 設定](./home/.chezmoitemplates/claude/settings-durable.json)和 [Codex hooks](./home/dot_codex/hooks.json.tmpl)。 |
| 本機驗證 | hook 會把已暫存的 chezmoi 來源快照渲染到暫存目錄，不會套用到家目錄。檢查項目包括 chezmoi 來源目錄是否指向這個 repository、skill 和共用規則的一致性、Bash／PowerShell 狀態列輸出，以及 Markdown 連結；其他測試涵蓋 profile 行為、workflow 刪除、Git 設定和公司 branch policy。 | [Pre-commit hook](./scripts/git-hooks/pre-commit)、[Bash 測試入口](./scripts/tests/run-git-bash-tests.ps1) 與[設定指南](./docs/setup.md)。 |
| 個人與工作用 AI 設定 | 機器本機的 `ai_context` 讓同一份設定來源能用於個人或工作環境，套用各自的 AI 指引與預設值。這台機器選用哪一套，不會提交到 Git。 | [`ai-profile` skill](./home/dot_agents/skills/ai-profile/SKILL.md) 與[profile 設定方式](./docs/chezmoi-workflow.md#machine-local-ai-context)。 |
| 檔案與材料整理 | 規格與參考資料、可重複使用的測試資料，以及交接紀錄分別放在 `~/Documents/` 下的不同目錄。任務如果用到多份資料，就在 issue、PR／MR 或一份狀態筆記中連結；使用外部材料前先確認來源。 | [專案材料規則](./home/.chezmoitemplates/core.md#project-material)與 [ADR-0053](./docs/decisions/0053-native-first-ai-workflows.md)。 |
| AI 協作防護與證據檢查 | 共用核心規則要求在信任邊界驗證輸入、保留輸出編碼、使用參數化 SQL，並避免把機密寫入或提交到 Git；也要求代理確認 checkout 和材料來源，且只回報實際執行過的檢查，目的是減少常見安全錯誤和未經驗證的完成宣稱。 | [共用核心規則](./home/.chezmoitemplates/core.md) 與 [ADR-0024](./docs/decisions/0024-instruction-provenance-and-material-filing.md)。 |

**狀態列範例。** 圖中的模型與用量是當時的數值。

![Claude Code 狀態列，顯示模型、session、專案目錄、Git branch、context 使用量和用量時段。](./docs/images/statusline.png)

## 檔案放在哪裡

| 路徑 | 內容 |
| --- | --- |
| [`home/`](./home/) | chezmoi 管理的目標設定來源。 |
| [`home/.chezmoitemplates/`](./home/.chezmoitemplates/) | 可重用的設定、指引本文和範本。 |
| [`home/dot_agents/skills/`](./home/dot_agents/skills/) | 共用 skill，以及依 client 限制的 skill 來源。 |
| `home/dot_<client>/` | 各 client 的原生入口，以及接上共用指引的精簡 wrapper。 |
| [`scripts/`](./scripts/) | bootstrap、診斷和驗證工具。 |
| [`docs/`](./docs/) | 設定步驟、AI 設定來源與支援對照、操作指南和架構決策紀錄。 |

這些都是可以單獨檢視和調整的例子。如果想試用整套設定，請先讀[設定指南](./docs/setup.md)，了解它會如何修改機器設定，以及套用前有哪些檢查步驟。

## 從這裡開始

- [設定一台新電腦](./docs/setup.md)
- [了解如何修改與套用受管理的設定](./docs/chezmoi-workflow.md)
- [查找 AI client 設定或 skill 的來源](./docs/customization-support.md)
- [查看目前有效的架構決策](./docs/decisions/README.md)

若要套用到自己的家目錄，請先讀設定指南，並針對自己的機器執行 `chezmoi diff` 檢查變更。
