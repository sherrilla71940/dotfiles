# 個人任務紀錄

[English](./task-record.md)

[`task-record` skill](../home/dot_agents/skills/task-record/SKILL.md) 讓不同 AI client 與 session 都能找到任務中的決策理由和待釐清問題。skill 定義 agent 的處理方式；本指南說明何時需要個人紀錄，以及它與其他資料來源的關係。紀錄放在 `~/Documents/task-records/{repo}/`，不屬於這個 repository，也不由 chezmoi 管理。

## 什麼時候需要紀錄

如果任務正等待會影響後續工作的外部答覆、某項決策的理由日後可能需要查證，或工作可能跨越多個 session，就為該任務保留一份紀錄。若請求和 Git 已足以還原一項簡單工作的脈絡，就不必建立紀錄。日後想查「當初為什麼這樣做」時，可搜尋已完成的紀錄，不必為查詢另建一份。

## 紀錄與其他資料的關係

```mermaid
flowchart LR
    task["需要保留脈絡的任務"] --> record["一份個人紀錄<br/>問題 · 決策理由 · 下一步"]
    originals["原始訊息與 issue"] -. "查證依據" .-> record
    git["Git 與實際驗證結果"] -. "行動前重新確認" .-> record
    record --> links["附用途的連結<br/>專案文件 · 參考材料 · 交接 · issue · PR/MR"]
    record --> resume["後續 session"]
    why["日後追問決策原因"] --> search["搜尋已完成的紀錄"]
    search --> evidence["核對所引用的來源"]
    resume --> evidence
    evidence --> act["繼續工作或說明決策"]
```

這份紀錄是個人使用的任務索引與決策歷程，不是供團隊共同維護的正式文件，也不必逐次記下每個 session 做了什麼。每逢重要進度，就更新原有摘要；已結束的實作只需留下結果和連結，決策理由則保留下來。外部請求和答覆仍以原始訊息或 issue 為準；程式碼狀態則以 Git 為準。若團隊需要審查或持續維護某項決策、缺口或待辦，應依專案規範記在正式的 issue、ADR、文件或交接紀錄中，再由個人紀錄附上用途明確的連結；不要另建一份平行清單。接手時應先查 Git 和引用來源，再採取行動。一般不必另外抄錄 branch、HEAD 或工作目錄是否乾淨；只有在不同 checkout、未提交變更或發布進度會影響下一步時，才留下標明日期的必要說明。參考材料、可重用的測試輸入和對外交接文件保留在各自的位置，紀錄只附上有用途的連結。

[紀錄格式](../home/dot_agents/skills/task-record/references/record-format.md)列出可使用的欄位。[ADR-0057](./decisions/0057-use-durable-personal-task-records.md)說明為何以此取代舊的 `task-handoff` 快照；[ADR-0061](./decisions/0061-keep-task-records-concise-and-project-outputs-canonical.md)補充接手資訊與團隊文件的分工。[端到端任務指南](./run-task-end-to-end.zh-TW.md)涵蓋實作、驗證與交付；跨 session 工作需要保留的脈絡則由任務紀錄承接。
