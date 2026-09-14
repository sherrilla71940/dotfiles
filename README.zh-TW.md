# Dotfiles

[English](README.md) · [繁體中文](README.zh-TW.md)

> **TL;DR：** 這是一套以 chezmoi 管理的跨平台開發環境，從單一來源產生 AI 用戶端的指示、技能、
> 規則（各用戶端支援的部分）與設定，以及 Shell、編輯器與工具所需的原生設定。每台電腦都可以
> 選擇個人或公司使用情境，並獨立開啟或關閉私有的專案任務交接功能。共用技能只維護一份，應用
> 程式自行管理的設定也會保留。

這個儲存庫是我個人維護、以 [chezmoi](https://www.chezmoi.io) 管理的跨平台 AI 開發環境與開發工具系統。
它從單一來源，在 Windows 和 macOS 上管理 Shell、編輯器、一般工具，以及 AI 用戶端的指示、技能、
規則與設定。

## 這個儲存庫提供什麼

- **Claude Code、Codex 和 GitHub Copilot 會使用許多相同的 AI 指示與技能，但各自要求不同的檔案
  與格式。** 儲存庫只在一處維護共用來源內容，並在產生時組合永遠載入的基線、選定的 personal
  或 company 情境、啟用時才加入的連續性指示，以及作業系統或用戶端專屬的分支。薄型轉接層再把
  組合後的內容產生為各工具使用的原生格式。部分內容會原樣共用，部分內容會依條件加入，部分
  內容則維持用戶端專屬。像可攜式技能這類可以完整共用的檔案，則使用 symlink，避免產生重複副本。
  `~/.claude/CLAUDE.md` 就會在產生時組合共用基線、選定的情境、啟用時的連續性指示，以及 Claude
  專屬區段。
- **同一台電腦可以同時支援個人與公司工作，不需要維護兩套分開的設定。** 兩個只在本機生效的
  選擇器會在產生設定時，組合共用基線、personal 或 company 情境，以及啟用時才加入的專案
  連續性指示。同一套共用技能、指示與規則來源，因此能依目前情境產生相應的工作流程，再由各
  用戶端的薄型轉接層產生它們原生格式的設定。`ai_context` 控制情境慣例與產出物的語言預設值。
  `ai_continuity` 則獨立控制另一項功能：一套保存在 `.project-continuity/state.md` 的私有任務
  交接機制、是否固定載入相關指示，以及工作階段開始與結束時的輔助程式是否自動回報或更新交接
  狀態。這份狀態會記錄目前工作的目標、所處階段、下一步、阻礙與假設。即使前一個工作階段達到
  token 上限、意外結束，或中斷幾天到幾週，新的 Claude Code 或 Codex 工作階段也能接續任務，
  不必從頭開始。關閉連續性後，這些自動回報與更新會停止，但連續性技能仍可在明確要求時使用。
  變更任一選擇器後，只有新產生的設定與
  新啟動的工作階段會套用變更；儲存庫與專案指示仍然優先。
- **不同電腦的設定會逐漸出現差異，而且不同作業系統的相同設定位於不同路徑。** Template 讓
  跨平台的受管理設定維持一致。新電腦只要複製本儲存庫，再用一個 chezmoi 指令產生所有
  受管理檔案即可；安裝工具的工作由各自的腳本負責，不會放進 apply 流程，因此一般套用
  設定時不會順便安裝軟體。
- **有些設定檔同時由儲存庫和使用它的應用程式管理。** 所謂受管理檔案，是指由 chezmoi
  從這個儲存庫產生的檔案；但應用程式也可能把自己的偏好設定寫進同一個檔案。如果每次都整個
  覆寫，就會把應用程式自己管理的內容一起清掉。Claude Code 的 `settings.json` 就是例子：儲存庫
  只管理少數需要長期同步的設定鍵，chezmoi 會把這些鍵合併到現有檔案，同時保留 Claude 的模型、
  推理程度、主題、權限和其他本機設定。

## AI 用戶端架構概覽

這張圖聚焦於 AI 用戶端與 profile 組合機制。它不是所有受管理目標的完整清單；Shell、
Git、Windows Terminal、一般 VS Code 設定，以及儲存庫工具，會走下文所述的簡單來源到
目標流程。

本儲存庫會在 Windows 或 macOS 上，為四個用戶端產生彼此協調的設定。請從左到右閱讀：
單一真實來源、每個用戶端的薄型轉接層、產生的目標，最後是讀取這些檔案的用戶端。

共用技能與規則本文只在一處維護。轉接層只加入各用戶端理解的中繼資料標頭（frontmatter）或
包裝，因此只適用於單一工具的規則不會被改寫成另一份工具中立的版本。

~~~mermaid
flowchart LR
    subgraph sourceState["來源（單一真實來源）"]
        core["core.md、情境層、continuity.md"]
        rules["規則本文<br/>依路徑套用"]
        vscodeBody["受管理的 VS Code 設定本文"]
        sharedSkills["dot_agents/skills<br/>共用技能，每個只保留一份"]
        clientSkills["用戶端專屬技能<br/>與用戶端入口"]
    end

    subgraph adapters["薄型轉接層"]
        claudeAdapter["Claude<br/>CLAUDE.md、規則帶有 paths:"]
        codexAdapter["Codex<br/>單一 AGENTS.md，不含 frontmatter"]
        copilotAdapter["Copilot<br/>指示帶有 applyTo:"]
        pathWrapper["作業系統路徑轉接層"]
        skillAdapter["symlink 轉接層"]
        clientSkillAdapter["各用戶端技能樹"]
    end

    subgraph renderedTargets["產生的目標"]
        claudeTarget["~/.claude"]
        codexTarget["~/.codex<br/>config.toml 由應用程式擁有"]
        copilotTarget["~/.copilot"]
        vscodeTarget["VS Code settings.json"]
        agentsTarget["~/.agents/skills"]
    end

    subgraph clients["用戶端"]
        claudeClient["Claude Code"]
        codexClient["Codex"]
        copilotClient["GitHub Copilot"]
        vscodeClient["VS Code"]
    end

    core --> claudeAdapter
    core --> codexAdapter
    core --> copilotAdapter
    rules --> claudeAdapter
    rules --> copilotAdapter
    sharedSkills --> skillAdapter
    clientSkills --> clientSkillAdapter
    vscodeBody --> pathWrapper

    claudeAdapter --> claudeTarget
    codexAdapter --> codexTarget
    copilotAdapter --> copilotTarget
    skillAdapter --> agentsTarget
    skillAdapter -.->|"symlink"| claudeTarget
    clientSkillAdapter --> claudeTarget
    clientSkillAdapter --> copilotTarget
    pathWrapper --> vscodeTarget

    claudeTarget --> claudeClient
    codexTarget --> codexClient
    copilotTarget --> copilotClient
    vscodeTarget --> vscodeClient
    agentsTarget --> codexClient
    agentsTarget --> copilotClient
~~~

儲存庫的其餘部分也遵循相同的來源到目標流程，只是不需要 AI 用戶端轉接層：
Shell 來源會產生 `~/.bashrc`、`~/.zshrc` 與 `~/.profile`；Git 來源會產生
`~/.gitconfig`；Windows Terminal 來源會產生平台設定；VS Code 來源則會在對應作業系統的
使用者設定檔中產生 keybindings、MCP 設定與一般設定。各作業系統的路徑包裝器只負責
選擇目的地，不會複製來源本文。

請注意圖中刻意省略的連線：`rules` 不會連到 Codex 轉接層。Codex 沒有匯入機制，也沒有
等同於路徑範圍限制的功能，因此它只會收到一份永遠載入且不含 YAML frontmatter 的單一檔案。

技能分成三個層級，因此圖中有兩個技能來源：

- **共用技能**只存在於 `home/dot_agents/skills`，並產生在 `~/.agents/skills`。Codex
  與 Copilot 直接探索該目錄；Claude Code 只會查看 `~/.claude/skills`，所以儲存庫
  會在那裡建立指向相同檔案的 symlink。技能本文仍然只有一份。
- **用戶端專屬入口**在同一項能力需要為不同用戶端提供不同入口時使用。`worktree-task-workflow` 在
  `dot_agents` 有受 Codex gate 控制的 `SKILL.md`，在 `dot_claude` 有 Claude 的
  `SKILL.md`；兩者都從 `.chezmoitemplates` 取得相同的參考本文，因此即使 frontmatter
  不同，指引仍不會分歧。
- **用戶端專屬技能**只供單一用戶端使用，不會共用：例如 Claude Code 的
  `claude-worktree-memory`，以及 Copilot 的 `remember`。Copilot 也有自己的
  `.agent.md` agents。

Worktree workflow 與 worktree manifest 在每種組合中都獨立可用；它們不受 profile 切換控制。
共用的輔助腳本會產生在 `~/.local/share`，讓 Claude Code 與 Codex 可以執行同一個檔案。

這些行為都有驗證，不是只靠約定維持。提交 hook 會重新產生已暫存的來源檔案；如果共用規則
本文分歧、技能因檔名屬性而消失、Codex 檔案出現 frontmatter、交叉參照指向不存在的標題，
或 Bash 與 PowerShell 的狀態輸出不一致，提交就會失敗。最後一項是少數刻意維護兩套實作的
內容之一。

## 運作方式

Chezmoi 會把本儲存庫的內容產生為應用程式實際讀取的檔案。`home/` 下的檔案是**來源狀態**：
這就是應該編輯並提交的設定來源。Chezmoi 寫入家目錄的檔案則是**目標檔案**。

~~~text
home/dot_bashrc  ──chezmoi apply──▶  ~/.bashrc
~~~

因此，請先修改來源檔，再執行 `chezmoi apply`，讓目標檔案與來源狀態一致。直接編輯
目標檔案不具持久性，下一次 apply 會覆寫它。檔名也帶有特殊意義：`dot_` 會產生開頭的
`.`，而 `.tmpl` 副檔名代表該檔案會以 template 方式產生；這就是同一份來源可以支援
Windows 與 macOS 的方式。

[docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) 說明日常操作。

`chezmoi init` 會把本儲存庫複製到它自行選擇的來源目錄。開始前，請先決定是否要讓工作
目錄位於方便使用一般 `git` 指令與儲存庫腳本的位置。本儲存庫的設定會把工作目錄放在
`~/dotfiles`，因此需要先自行複製到該位置。[docs/setup.md](./docs/setup.md) 說明設定順序；
這樣安排的原因請參閱 [ADR-0006](./docs/decisions/0006-keep-the-working-tree-at-dotfiles.md)。

## 共用 AI 設定

每個工具都會收到符合自身格式的檔案：Claude 規則帶有 `paths:`，Copilot
`.instructions.md` 帶有 `applyTo:`，Codex 則收到一份沒有 frontmatter 的單一檔案，
因為 Codex 既不能匯入其他檔案，也沒有路徑範圍限制功能。沒有任何一份共用檔案能直接服務
三個工具，因此本文會在產生時轉換，而不是直接連結。

~~~text
home/.chezmoitemplates/rules/javascript.md   <-- 只維護一份的本文
home/.chezmoidata.yaml                       <-- 只維護一份的 glob

  -> ~/.claude/rules/javascript.md                        paths: "**/*.{js,jsx,ts,tsx}"
  -> ~/.copilot/instructions/javascript.instructions.md   applyTo: "**/*.{js,jsx,ts,tsx}"
~~~

可攜式技能則採用相反做法，因為它們的指示不需要依用戶端改寫。實際檔案只保留一份，位於
`~/.agents/skills`，由 Codex 與 Copilot 直接讀取；Claude Code 只會查看
`~/.claude/skills`，因此在那裡建立 symlink。Codex 專用的例外也可以放在
  `~/.agents/skills`，但儲存庫的 host gate（主機篩選機制）會避免 Claude 與 Copilot 把它當成共用工作流程
來執行。

只給單一工具使用的技能或指示，會是該工具資料夾中的一般檔案，例如
`~/.copilot/skills` 中的檔案，不使用 template，也不建立 symlink。任何內容都不會被改寫成
工具中立的複本：只有單一工具能遵循的規則，就留在該工具的檔案中，或明確寫出適用的工具。

## 選擇 AI 設定 profile

Claude Code、Codex 與受管理的 VS Code Copilot 設定，使用 chezmoi 設定檔中的兩個獨立選擇器；
它們只在本機生效（`chezmoi edit-config`）：

~~~toml
[data]
ai_context = "company"        # 明確選擇工作電腦情境
ai_continuity = "on"           # 明確選擇連續性設定
~~~

[本機 AI profile 選擇器指南](./docs/chezmoi-workflow.md#machine-local-ai-profile-selectors)
是四種組合、缺少鍵時的預設值、無效值行為，以及選擇器只在各台 Windows 或 macOS 電腦上生效
的完整說明。

選定的情境會提供產出物的語言預設值：personal 使用英文（`en`），company 使用繁體中文
（`zh-TW`；現有介面接受該值時會表示為 `zhtw`）。明確傳入的語言參數、儲存庫指示與
使用者直接提出的要求都優先於這項預設值。使用者層級的 dotfiles 與 AI 設定在兩種情境中
都維持英文。Worktree 技能在兩種情境中都會安裝並可獨立使用；它們可以在連續性啟用時使用
專案連續性，但不是 profile 開關。

個人電腦可以完全省略 `ai_context`；工作電腦則使用 `chezmoi edit-config` 將它設為
`company`。本 dotfiles 儲存庫是刻意的例外：根目錄的 `AGENTS.md` 是儲存庫指示，會將在
本儲存庫中工作時的有效情境固定為 `personal`。因此，即使電腦明確選擇 `company`，這裡的
工作內容仍會維持英文。

變更選擇器後，請先用 `chezmoi diff` 預覽，確認內容後再套用，並重新啟動 AI 用戶端的工作
階段。已經執行中的工作階段會保留啟動時載入的情境。V1 的選擇器是整台電腦共用的，因此
同一台電腦上同時執行的工作階段不能安全地使用不同的情境或連續性設定。目前尚未提供 profile
CLI；廣泛的 Copilot 整合（技能探索、儲存庫指示與 agent plugin）也不在此版本範圍內。

### 選擇器會改變什麼

兩個選擇器都只存在於本機，不會提交到儲存庫。解析器（resolver）會先驗證它們，再分別決定：
要組合哪一個情境層、是否啟用專案連續性指示，以及工作階段開始與結束時是否自動回報或更新狀態，
還有支援的產出物預設使用哪種語言。

~~~mermaid
flowchart TD
    config["chezmoi 設定檔<br/>只在本機生效，不會提交"]
    config --> context["ai_context<br/>personal 或 company，預設 personal"]
    config --> continuitySelector["ai_continuity<br/>on 或 off，預設 on"]

    context --> resolver["ai-profile.yaml<br/>驗證選擇器；無效值會使產生失敗"]
    continuitySelector --> resolver

    resolver --> layer["情境層<br/>profiles/personal.md 或 profiles/company.md"]
    resolver --> gate["連續性閘門"]
    resolver --> language["artifact_language<br/>en 或 zhtw"]

    layer --> instructions["永遠載入的指示<br/>在 core.md 中組合"]
    gate --> instructions
    gate --> helper["maintain-project-continuity.sh<br/>啟用時回報，停用時不輸出也不修改狀態"]

    language --> commitSkill["git-commit-action"]
    language --> worktreeText["worktree 呼叫與發布"]
    language --> vscodeCommit["VS Code Copilot 提交訊息"]

    repository["儲存庫 AGENTS.md 或 CLAUDE.md"] -.->|"優先於本機情境"| instructions
~~~

圖中有三個細節很容易理解錯：

- **產出物語言會傳到技能與 VS Code，不只傳到指示檔。** 這三個項目就是目前支援的完整
  範圍；明確指定 `en` 或 `zhtw` 時，仍會覆寫預設值。
- **停用連續性會改變指示與輔助程式行為，但不會改動 hook 設定。** Hook 在兩種狀態下都
  會保留，這樣獨立的 worktree 啟動檢查仍然有效，Codex 也不必因為切換設定而重新核准
  每個 hook 項目。
- **儲存庫指示優先於本機情境。** 因此本儲存庫自己的 `AGENTS.md` 會將在此工作的情境
  固定為 `personal`，而不需要修改本機選擇器。

使用者層級的設定與自訂內容註解在兩種情境中都維持英文；連續性狀態也不論對話使用哪種
語言，都會以英文寫入。

## 選擇設定方式

### 全新電腦

只有在不需要保留既有 Shell、編輯器或 AI 用戶端設定時，才使用這個單行設定方法。Windows
使用者請先依照[設定前置條件](./docs/setup.md#enable-windows-symlink-creation)啟用
Developer Mode，或提供建立 symbolic link 所需的權限。

以下指令會下載並執行遠端安裝程式。請先確認你信任來源，並已檢查本機的 URL 與腳本政策，
再執行它。

~~~bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply sherrilla71940
~~~

### 已有設定的電腦

如果有任何設定需要保留，或你不確定是否需要保留，請先初始化但不要套用：

~~~bash
chezmoi init sherrilla71940
git -C "$(chezmoi source-path)" rev-parse --show-toplevel   # 必須是此儲存庫
chezmoi diff
~~~

在採用想保留的設定（也就是將它們複製進儲存庫）之前，不要套用。請參閱
[既有設定指南](./docs/setup.md#existing-configuration)，了解如何保留完整的一般檔案，或
從 template 產生的檔案中只保留選定設定。如果使用 fork，請將 `sherrilla71940` 替換為
fork 的 URL。

以上任一方式都只是七個步驟中的第一步。接下來還要執行會連結來源目錄並啟用驗證 hook 的
bootstrap 輔助程式、安裝並登入應用程式，然後**再次執行 bootstrap**，讓 plugin、extension
與 MCP 步驟能找到它們需要的 CLI。完整流程請參閱 [docs/setup.md](./docs/setup.md)；只
停在這裡只會有檔案，沒有完整的工具環境。

## 設定完成後

無論目前在哪個目錄，你都可以執行這些指令。Chezmoi 會使用已設定的來源目錄，因此不必先切換目錄，
`chezmoi edit`、`chezmoi diff`、`chezmoi apply` 與 `chezmoi git` 都能直接使用。
儲存庫根目錄（如果保留預設位置就是 `~/dotfiles`，也可以用 `chezmoi cd` 開啟）只是方便
執行一般 `git` 指令與儲存庫腳本的地方。

### 修改設定

修改來源、用 `chezmoi diff` 預覽、執行 `chezmoi apply`，最後提交。套用完成後，
`chezmoi status` 應該會是空的。

在儲存庫根目錄執行 `bash scripts/dotfiles doctor`，可以取得一份健康檢查報告，內容包括
chezmoi 來源識別、解析後的本機 profile、尚未套用的目標差異、Claude 的共用技能連結，
以及必要的工具版本。這個工具位於 `scripts/`，因為它要檢查來源 checkout 與 live chezmoi
狀態；它是儲存庫工具，不是會產生到每台電腦使用者家目錄的設定指令。

其餘不由儲存庫管理的內容則是例外；應用程式記錄的大部分資料都屬於這一類。Claude 的
`settings.json` 是最明顯的例子：儲存庫只管理應該在各台電腦一致的鍵，模型、主題、
權限等其餘內容則留在本機。請在用戶端內使用 `/config`、`/model` 或 `/plugin`
修改它們，不需要套用或提交。執行 `scripts/diagnostics/claude-settings-drift.sh` 可以
查看目前的管理分界；一般流程請參閱 [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md)。

### 也可以直接向 AI 助手描述需求

你可以用日常語言向 Claude Code、Codex 或 VS Code 中的 GitHub Copilot 描述想要的結果，
不必先熟悉 chezmoi 編碼過的來源檔名或指令。例如：

- 「請帶我了解如何用這個儲存庫管理 dotfiles。」
- 「新增 Claude Code 與 Copilot 共用的 React 指示，並說明 Codex 支援哪些內容。」
- 「只為 Claude Code 新增這項指示。」
- 「我直接修改了 live 的 `.bashrc`，請幫我把變更保留到儲存庫。」
- 「把 VS Code 字型大小設為 14，提交來源變更，然後安全地用 chezmoi 套用。」

儲存庫層級的 [AGENTS.md](./AGENTS.md) 會告訴每個助手如何將需求轉換成安全的來源狀態
變更，並區分編輯、套用與提交。Claude 會透過 [CLAUDE.md](./CLAUDE.md) 取得它；
Codex 與 Copilot 可以直接讀取 `AGENTS.md`。

從儲存庫根目錄啟動工作階段最簡單，因為每個工具都會自行載入該目錄的指示。即使從其他
位置開始也一樣有效：本儲存庫安裝的共用核心指示會要求每個助手在修改設定前先用
`chezmoi source-path` 找到來源，並先讀取本儲存庫的 `AGENTS.md`。因此，即使助手從未
接觸過本儲存庫，也能取得來源與目標的規則以及結構限制。

## 只複製本儲存庫的一部分

只取出 `home/.chezmoitemplates/` 中的單一檔案並不能運作，因為其中沒有任何檔案是目標檔；
每個檔案都是由某個 wrapper 產生的本文。VS Code 本文需要 `home/AppData/` 或
`home/Library/` 底下的作業系統專用 wrapper；共用規則本文刻意省略每個用戶端要求的
frontmatter；Claude 的 durable-settings 本文也必須搭配 `home/dot_claude/modify_settings.json`
才能合併。請一併取得 wrapper，或先閱讀它，了解它提供了哪些內容。

`home/dot_agents/skills/` 底下的技能是真正的檔案，不是本文，因此可以直接複製。大多數
技能都可攜；只有來源端的 `.codex-only` marker 代表需要 host gate 的例外。將技能放入
單一用戶端的設定前，請先確認這項限制。

## 目錄結構

~~~text
home/                            chezmoi 來源狀態
  .chezmoidata.yaml              規則 glob，集中管理
  .chezmoitemplates/             共用本文（core.md、profiles/、rules/、vscode/、claude/）
  dot_claude/                    CLAUDE.md、規則、設定、hook、指令、agent、
                                 Claude 專屬技能，以及指向共用技能的連結
  dot_codex/                     AGENTS.md、config.toml（技能來自 dot_agents）
  dot_copilot/                   指示、agent、Copilot 專屬技能
  dot_agents/skills/             可攜式與受 host gate（主機篩選機制）管理的 Codex 技能 -> ~/.agents/skills
  .README.md                     如何閱讀這棵樹（只存於儲存庫，不會部署）
  dot_bashrc  dot_zshrc.tmpl  dot_bash_profile   Shell 設定
  AppData/ · Library/            每個作業系統一份的 VS Code 設定
scripts/dotfiles                 儲存庫工具入口（bash scripts/dotfiles doctor）
scripts/bootstrap/                一次性新電腦設定（手動執行）
scripts/install/                  Claude MCP 安裝程式
scripts/manifests/                MCP 與 VS Code extension manifest
scripts/diagnostics/              doctor、Claude 設定差異與工作階段使用量報告
scripts/tests/                    profile、連續性與 worktree 回歸測試
scripts/git-hooks/pre-commit     每次提交前驗證來源狀態
scripts/git-hooks/markdown-anchors.awk
                                 解析文件交叉參照
docs/decisions/                  架構決策與重新評估條件
~~~

## 維護者回歸測試

以下腳本是長期保留的回歸測試。只要它們保護的行為仍受支援，就請保留測試；只有在功能
退役，或已有等價覆蓋取代時，才移除測試。

| 變更內容 | 執行方式 |
| --- | --- |
| Windows worktree 建立實作 | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test-git-worktree-provision.ps1` |
| macOS worktree 建立實作 | `bash scripts/tests/test-git-worktree-provision.sh` |
| 共用 worktree 建立契約或安全邊界 | 執行兩套 worktree 建立測試 |
| Project-continuity 生命週期 hook 或復原契約 | `bash scripts/tests/test-project-continuity-hook.sh` |
| AI profile 選擇器、組合、語言預設或連續性切換 | `bash scripts/tests/test-ai-configuration-profiles.sh` |
| `.chezmoiignore` 作業系統篩選、任一 VS Code 設定樹或任一 worktree 輔助程式 | `bash scripts/tests/test-ai-configuration-profiles.sh`；它會從本機產生 darwin 與 windows 兩個分支，因此不會漏測另一個平台的 template |

這些測試會建立暫時的儲存庫，並在實作或契約變更時手動執行。Pre-commit hook 則維持快速，
專注於來源產生與結構檢查。

## 接下來要去哪裡

| 我想要…… | 請閱讀 |
| --- | --- |
| 設定電腦，或確認哪些應用程式需要自行安裝 | [docs/setup.md](./docs/setup.md) |
| 新增、修改或移除一般受管理檔案 | [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) |
| 新增或修改 AI 指示、技能、agent、prompt、MCP server 或 plugin | [docs/customization-support.md](./docs/customization-support.md) |
| 了解被忽略的本機檔案如何進入新的 Git worktree | [docs/worktree-provisioning.md](./docs/worktree-provisioning.md) |
| 了解本儲存庫為什麼採用目前的結構 | [docs/decisions/README.md](./docs/decisions/README.md) |
| 在刪減規則前了解它存在的原因 | [docs/rule-rationale.md](./docs/rule-rationale.md) |
| 讓程式設計助手在本儲存庫中工作 | [AGENTS.md](./AGENTS.md) |

這份 README 是給人閱讀的繁體中文入口；由工具載入的 `AGENTS.md`、`CLAUDE.md`、技能、
指示與連續性狀態仍維持英文。詳細技術指南目前也維持英文，因為它們同時是維護流程與
AI 工作階段會參考的來源文件。

`AGENTS.md` 是這裡唯一主要供工具讀取、而不是供人閱讀的檔案：Codex 與 Copilot CLI 會自動載入
它，根目錄的 `CLAUDE.md` 會匯入它，讓 Claude Code 也取得相同限制。它刻意保持精簡，
因為每個 AI 工作階段都會佔用 context；操作流程則放在各自的任務指南中。
