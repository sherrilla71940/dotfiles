# 跨專案平行工作

[English](./parallel-work.md)

每個獨立的工作項目都使用不同的 client task 或 session。修改前，先確認各自連到預期的 repository 與工作目錄。若多個 subagent 要從同一項工作分頭處理，請在各自的任務指示中寫明預期的起始 branch 或 commit；開始修改前，確認 Git root、branch（或 detached 狀態）及實際起始 commit 都相符。不同 repository 可以各自並行處理。

同一個 repository 若要同時進行不同修改，且規則允許，請使用不同 worktree，避免多個工作項目同時修改同一個 checkout。每個 worktree 的檔案、index 與 HEAD 各自獨立；但 client 的設定可能會複製、連結或共用 Git 忽略的檔案與依賴目錄（例如 `node_modules`）。Git refs、port、資料庫及 cache 等專案資源也可能共用。安裝或清除依賴前，先確認指令會更動的實際路徑，以及是否有其他 checkout 正在使用；依專案支援的隔離方式處理，或先協調共用資源。如果 repository 規定只能使用同一個 checkout，就在該 checkout 協調修改，不要違反規則另開 worktree。

讓每個工作項目保有自己的脈絡，並遵守所屬 repository 的指引與檢查。工作若會跨 session 進行，或需要保留後續可查的決策，可使用[個人任務紀錄](./task-record.zh-TW.md)。個別實作任務若要呼叫 skill，請參考[端到端任務指南](./run-task-end-to-end.zh-TW.md)。優先使用 client 原生的 task 與 worktree 功能；若 client 沒有提供，可在 repository 規則允許時使用一般 Git worktree。不需要中央排程器。
