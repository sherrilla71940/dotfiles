# 跨專案平行工作

[English](./parallel-work.md)

每個獨立的工作項目都使用不同的 client task 或 session。修改前，先確認各自連到預期的 repository 與工作目錄。不同 repository 可以各自並行處理。

同一個 repository 若要同時進行不同修改，且規則允許，請使用不同 worktree，避免多個工作項目同時修改同一個 checkout。每個 worktree 都有自己的檔案、index 與 HEAD；Git refs 及 port、資料庫、cache 等專案服務仍會共用，請依專案的執行環境設定處理。如果 repository 規定只能使用同一個 checkout，就在該 checkout 協調修改，不要違反規則另開 worktree。

讓每個工作項目保有自己的脈絡，並遵守所屬 repository 的指引與檢查。工作若會跨 session 進行，或需要保留後續可查的決策，可使用[個人任務紀錄](./task-record.zh-TW.md)。個別實作任務若要呼叫 skill，請參考[端到端任務指南](./run-task-end-to-end.zh-TW.md)。優先使用 client 原生的 task 與 worktree 功能；若 client 沒有提供，可在 repository 規則允許時使用一般 Git worktree。不需要中央排程器。
