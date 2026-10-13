# 我的個人 Dotfiles 與 AI 設定

[English](./README.md)

**個人開發環境設定與共用 AI 指引的版本控制來源。**

這是我公開分享的個人設定，供其他開發者參考其中的設計取捨；不適合不經修改就直接套用。repository 收錄長期保留的設定與共用 AI 指引，不包含憑證、session 記錄等應用程式或帳戶資料。

## 為什麼建立這個 repository

電腦和開發工具一換，dotfiles 設定就容易在不同機器間走樣；AI 指引在不同 AI client 間也容易走樣，例如 Claude Code、Codex 和 GitHub Copilot。

設計時主要考量以下幾點：

- **重現設定：** bootstrap 腳本安裝我使用的工具，chezmoi 套用我選擇帶到不同機器的長期設定。
- **選擇性管理設定：** 我只將希望在不同機器保持一致的長期設定納入版本控制；容易變動或未列入 repository 的偏好則交由各 client 管理。例如，repository 管理 Claude Code 的 hooks 和狀態列，模型與推理強度則由 Claude Code 自行管理。
- **維持 AI 指引一致：** 共用規則與 skill 維持單一來源，減少不同 client 間的內容走樣。
- **預覽後再套用：** Git 可檢視來源檔的修改，`chezmoi diff` 預覽這台機器會套用的結果，讓我能先發現非預期變更。

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
    subgraph clients["AI client"]
        ai["由 chezmoi 管理的長期設定<br/>Claude Code · Codex · GitHub Copilot"]
        appstate["client 自行管理的狀態<br/>session · 憑證 · 執行時偏好<br/>（chezmoi 不管理）"]
    end
    render --> ai
    render --> settings["Shell · Git · editor · terminal<br/>以及其他長期保留的設定"]
```

共用規則與可跨 client 使用的 skill 由共用來源維護；client 專屬的指引、skill 與設定，則只套用到支援它們的 client。

chezmoi 會依這台機器的 profile，產生各工具需要的設定檔。我在 repository 中編輯可讀的來源檔，檢查產生的設定，再將確認過的變更套用到家目錄。各 client 仍自行管理 session、憑證與執行時狀態。

## 工作流程與文件

| 想做什麼 | 從哪裡開始 | 它會怎麼做 |
| --- | --- | --- |
| 在不同 client 共用 AI 指引 | [AI 設定支援對照](./docs/customization-support.md) | 共用規則與 skill 會送到 Claude Code、Codex 和 GitHub Copilot 支援的設定位置；client 專屬行為只套用在支援它的 client。 |
| 實作、驗證與交付 | [端到端任務指南](./docs/run-task-end-to-end.zh-TW.md) | 從檢查 repository 與材料、實作到驗證，最後完成本機 commit，或依要求建立 PR／MR。 |
| 驗證前端畫面修改 | [Web UI 驗證 skill](./home/dot_agents/skills/web-ui-verification/SKILL.md) | 在執行中的應用程式檢查修改路徑、狀態、互動方式與相關 viewport。 |
| 平行處理多個專案 | [平行工作指南](./docs/parallel-work.zh-TW.md) | 確認各工作流使用正確的 repository；同一 repository 的並行修改會在規則允許時以 worktree 隔離。 |
| 在不同 AI session 間保留並查找任務決策 | [個人任務紀錄指南](./docs/task-record.zh-TW.md) | 以一份個人紀錄保留問題、附來源的答覆、決策與下一步，讓後續 AI session 能接續工作，也能查明當初的決策理由。 |

## 功能與防護措施

| 功能 | 用途 | 查看實作 |
| --- | --- | --- |
| Claude Code 狀態列（Bash 與 PowerShell） | 依終端機寬度顯示模型、session、Git 狀態，以及可用時的用量資訊。 | [Bash](./home/dot_claude/claude-session-statusline.sh)、[PowerShell](./home/dot_claude/claude-session-statusline.ps1) |
| 桌面通知（Windows 與 macOS） | 在終端機或 VS Code session 中，針對回覆完成、Claude subagent 狀態及工具授權發出通知。 | [Windows](./home/dot_local/share/show-agent-notification.ps1)、[macOS](./home/dot_local/share/show-agent-notification-macos.sh)、[Claude 設定](./home/.chezmoitemplates/claude/settings-durable.json)、[Codex hooks](./home/dot_codex/hooks.json.tmpl) |
| 本機驗證 | Pre-commit hook 會在暫存目錄渲染並驗證已暫存的來源，不會套用到家目錄；再視變更內容檢查共用指引與連結。若 PowerShell 和 jq 可用，也會比對狀態列輸出；缺少工具時會明確提示略過。 | [Hook](./scripts/git-hooks/pre-commit)、[測試入口](./scripts/tests/run-git-bash-tests.ps1) |
| 個人與工作用 AI 設定 | 機器本機的 `ai_context` 決定使用哪套指引與預設值，不會將選擇提交到 Git。 | [`ai-profile`](./home/dot_agents/skills/ai-profile/SKILL.md)、[profile 設定方式](./docs/chezmoi-workflow.md#machine-local-ai-context) |
| 專案材料存放與索引 | 將穩定參考資料、可重用的測試輸入、個人任務紀錄及對外交接文件分開存放。 | [專案材料規則](./home/.chezmoitemplates/core.md#project-material)、[ADR-0057](./docs/decisions/0057-use-durable-personal-task-records.md) |
| 安全與驗證防護 | 共用規則涵蓋輸入驗證、輸出編碼、機密保護，以及有憑有據的完成回報。 | [共用核心規則](./home/.chezmoitemplates/core.md)、[ADR-0024](./docs/decisions/0024-instruction-provenance-and-material-filing.md) |

**狀態列範例。** 圖中的模型與用量是當時的數值。

![Claude Code 狀態列，顯示模型、session、專案目錄、Git branch、context 使用量和用量時段。](./docs/images/statusline.png)

## 檔案放在哪裡

| 路徑 | 內容 |
| --- | --- |
| [`home/`](./home/) | chezmoi 管理的目標設定來源。 |
| [`home/.chezmoitemplates/`](./home/.chezmoitemplates/) | 可重用的設定、指引本文和範本。 |
| [`home/dot_agents/skills/`](./home/dot_agents/skills/) | 共用 skill，以及依 client 限制的 skill 來源。 |
| `home/dot_<client>/` | 各 client 專屬的設定，以及接上共用指引的精簡 wrapper。 |
| [`scripts/`](./scripts/) | bootstrap、診斷和驗證工具。 |
| [`docs/`](./docs/) | 設定步驟、AI 設定來源與支援對照、操作指南和架構決策紀錄。 |

## 從這裡開始

- [設定一台新電腦](./docs/setup.md)
- [了解如何修改與套用受管理的設定](./docs/chezmoi-workflow.md)
- [查找 AI client 設定或 skill 的來源](./docs/customization-support.md)
- [查看目前有效的架構決策](./docs/decisions/README.md)

若要套用到自己的家目錄，請先讀設定指南，並針對自己的機器執行 `chezmoi diff` 檢查變更。
