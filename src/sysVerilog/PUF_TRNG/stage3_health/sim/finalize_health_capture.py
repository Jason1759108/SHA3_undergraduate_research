import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'captures/board_21600/health_20261111';N=OUT/'nist_results'
oldout=ROOT.parent/'stage2_entropy/captures/board_21600/assessment_20261111'
integrity=json.loads((OUT/'integrity_review.json').read_text())
rows=json.loads((N/'restart_summary.json').read_text())
assert len(rows)==9
assert all(x['restart_passed'] for x in rows),'Some restart tests failed; preserve and investigate'
assert all(x['retained_statistical_estimate'] is not None for x in rows)
old=json.loads((oldout/'assessment_summary.json').read_text())
prev={x['label']:x for x in old['assessments']}
stats=json.loads((OUT/'descriptive_review.json').read_text())
assert not stats['duplicate_full_batch_groups'] and not stats['duplicate_first32_groups']
assert all(c['stuck_batches']==0 for c in stats['channels'])
minimum=min(x['retained_statistical_estimate'] for x in rows if x['bits_per_symbol']==1)
summary={'date':'2026-11-11','board_id':'21600','build_id':integrity['build_id'],
    'functional_batches':16,'assessment_batches':1000,'payload_samples':1024000,
    'integrity':'PASS','recorded_rct_faults':0,'recorded_apt_faults':0,
    'all_capture_health_states_valid':True,'ro_off_confirmed':True,
    'non_iid_assessments_completed':9,'ro_restart_tests_passed':9,
    'initial_joint_statistical_estimate':rows[0]['initial_statistical_estimate'],
    'retained_joint_statistical_estimate':rows[0]['retained_statistical_estimate'],
    'lowest_retained_channel_estimate':minimum,
    'monitor_assumption_per_channel':.5,'this_dataset_estimates_exceed_monitor_assumption':minimum>.5,
    'validated_entropy_credit':None,'physical_entropy_certified':False,
    'stage_status':'Candidate health-monitored raw source acceptance completed for this board/build/session; ready for SHA3 functional integration research',
    'assessments':rows,'limitations':['Data estimates and ordinary on-board functionality, not physical entropy certification or cross-condition guarantee.',
      'Startup samples discarded by hardware are not present in raw exports; their successful checks are represented by health/status counters.',
      'RO7 time correlation and bias increased relative to the older build; do not claim uniformly improved quality.',
      'Restart rows use first available payload after startup checks; not whole-board power cycling.',
      'No physical board fault injection; failure handling evidence is from simulation and host tests.',
      'Monitoring assumption 0.5 is not assigned as guaranteed entropy credit; do not sum per-channel values.']}
(OUT/'assessment_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
lines=['# 健康監測版實板驗收與熵評估（2026-11-11）','','## 結論','','板號 21600，版本 `'+integrity['build_id']+'`，divider 512。本輪 16 批功能驗收、1000 批固定設定復測、9 組非 IID 統計估計與 9 組 RO 重啟測試均已完成，重啟測試通過。此版本在本輪操作條件下的研究候選驗收可結案，下一步可進入 SHA3 功能整合；不再追加相同參數掃描。','','原始八路聯合樣本的初估為 {:.6f} bits/樣本；重啟評估後保留 **{:.6f} bits/八路樣本**。保留值是資料統計估計，沒有設定為保證熵信用，也不是完整標準認證。'.format(rows[0]['initial_statistical_estimate'],rows[0]['retained_statistical_estimate']),'','## 每路結果','','| 資料 | 初估（bits/樣本） | 重啟後保留 | 舊版重啟後保留 | 本輪 RO 重啟 |','|---|---:|---:|---:|---|']
for x in rows:
    label='八路聯合' if x['label']=='joint' else 'RO '+x['label'].split('_')[1]
    lines.append('| {} | {:.6f} | {:.6f} | {:.6f} | 通過 |'.format(label,x['initial_statistical_estimate'],x['retained_statistical_estimate'],prev[x['label']]['retained_statistical_estimate_rounded_by_tool']))
lines+=['','兩版重新佈局，啟動取樣方式與實驗時段也不同，不能將差異單獨歸因於健康監測，或將較高的初估直接解讀為更安全。逐路下界的鬆緊與聯合估計不同，不能把各路數字相加當作聯合信用。','','## 功能與完整性','','- 16 批功能資料、1000 批評估資料的 health 狀態均符合：status=194、count=1024、startup_seen=1024、observed=2048；RO enable、RCT/APT/合併故障遮罩均為 0。','- 已核對 raw/metadata 校驗值、63 組索引與發布快照，符合本機已驗證的硬體版本。','- 在獨立副本重匯出資料：10 個二進位檔逐 byte 相同，dataset manifest 解析後相同；原始下載檔不修改。','- notebook 7 個非空程式格均有執行紀錄，沒有錯誤輸出。僅讀取下載 notebook 的 JSON，不執行其中程式碼。','- 完成且 RO 關閉；沒有卡死通道、整批重複或前 32 bytes 完全重複。','- 每批 1024 個 startup 樣本由硬體檢查並丟棄；目前檔案只有 payload。無法由 raw 檔獨立重播未保存的 startup 位元，啟動檢查結果依健康狀態、計數及硬體驗證紀錄。','','## 仍需如實保留的現象','','| 通道 | 1 比例 | 批內 lag1 相關平均 | lag1 絕對值第 95 百分位 |','|---:|---:|---:|---:|']
for ch in stats['channels']:
    a=next(v for v in stats['within_batch_lag'] if v['channel']==ch['channel'] and v['lag']==1)
    lines.append('| {} | {:.4%} | {:.5f} | {:.5f} |'.format(ch['channel'],ch['ones_fraction'],a['mean'],a['p95_abs']))
lines+=['','RO7 的時間相關及偏置比第二階段較明顯，個別路的保留熵估計也下降。RCT/APT 主要偵測卡死與比例退化，不保證偵測所有可預測性或相關；因此「沒有健康警報」不等於熵已滿或八路獨立。這個現象不隱藏，也沒有刪掉 RO7 或捨棄較差批次來提高結果。','','各路本批保留估計的最小值 {:.6f}，高於目前 H_monitor=0.5 的研究監測假設；只表示這次資料估計未否定這項設定，不是對全部工作條件或條件最小熵的證明。'.format(minimum),'','## 工具與邊界','','沿用第二階段固定版本 NIST 工具，執行前核對兩個執行檔 SHA-256 完全相同；沿用原 11 組官方參考自測與正/負重啟控制的證據，未因無變更而重跑。Windows 相容版本僅替換重啟模擬器的亂數種子來源，估計演算法與測試資料不變，詳 nist_results/tool_provenance.json 與前階段驗證紀錄。完整命令、回傳碼及日誌均保留。','','重啟矩陣取「1024 點啟動檢查完成後的前 1000 個可用 payload」，符合本版實際操作的可用資料定義。RO 啟停不等於整張板重新上電；分批資料之間有間隙。板上 UTC 未校準，日期以操作者 2026-11-11 記錄為準。','','本輪只有一張板、一個硬體版本/設定與一個實驗時段，溫度/電壓未獨立量測。故障處理以本機 RTL/系統/host 測試為證據，本輪沒有實板故障注入。仍未宣稱完整 SP800-90B 符合性、抗干擾能力或正式熵信用。','','## 明確的下一步','','不再收同一版本同一參數的資料來替代整合工作。下一版將健康來源與 SHA3 放在同一個新 overlay，避免載入第二份 bitstream 覆蓋第一個電路。先以 PS 橋接通過健康檢測的原始批次到 SHA3，驗證雜湊結果與故障時不輸出有效結果；功能整合與熵量保證分開。','','候選功能流程可先固定每次使用完整 1024-byte 健康 payload、輸出一個 SHA3-256 digest；這只定義功能封包，不能因此自動宣稱每個輸出含 256 bits 真實熵。新整合實作的原始資料與控制路徑需一次整合驗收，舊版本結果不直接當作新布局已通過。']
(OUT/'REVIEW.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({k:summary[k] for k in ['integrity','non_iid_assessments_completed','ro_restart_tests_passed','retained_joint_statistical_estimate','lowest_retained_channel_estimate','validated_entropy_credit']},indent=2))
