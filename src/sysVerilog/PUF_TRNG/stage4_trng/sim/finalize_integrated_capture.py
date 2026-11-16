"""Summarize retained board evidence and all nine raw-source assessments.

No notebook is executed; no board is accessed; entropy credit stays unvalidated.
"""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'captures/board_21600/integrated_20261116'


def main():
    integrity=json.loads((OUT/'integrity_review.json').read_text(encoding='utf-8'))
    stats=json.loads((OUT/'descriptive_review.json').read_text())
    initial=json.loads((OUT/'nist_results/non_iid_summary.json').read_text())
    restarts=json.loads((OUT/'nist_results/restart_summary.json').read_text())
    executions=json.loads((OUT/'nist_results/execution_index.json').read_text())
    expected={'joint'}|{'channel_'+str(k) for k in range(8)}
    assert integrity['status']=='PASS'
    for name,record in integrity['artifacts'].items():
        assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==record['sha256']
    assert len(initial)==len(restarts)==9 and {x['label'] for x in initial}=={x['label'] for x in restarts}==expected
    assert len(executions)==18 and len({x['label'] for x in executions})==18
    assert all(x['returncode']==0 for x in executions)
    assert all(x['restart_passed'] and x['returncode']==0 for x in restarts)
    for item in restarts:
        assert abs(item['retained_statistical_estimate']-min(item['initial_statistical_estimate'],item['restart_H_r'],item['restart_H_c']))<1e-6
    joint=next(x for x in restarts if x['label']=='joint')
    channels=[next(x for x in restarts if x['label']=='channel_'+str(k)) for k in range(8)]
    previous=json.loads((ROOT.parent/'stage3_health/captures/board_21600/health_20261111/assessment_summary.json').read_text())
    with zipfile.ZipFile(OUT/'2026-11-16_20261115T064320Z_80de3249.zip') as z:
        elapsed=[json.loads(z.read('batch_%04d.json'%k))['elapsed_seconds'] for k in range(1000)]
    summary={
        'status':'PASS_FUNCTIONAL_BOARD_ACCEPTANCE_AND_LIMITED_RAW_ASSESSMENT',
        'experiment_date':'2026-11-16','board_id':'21600',
        'build_id':next(iter(integrity['collections'].values()))['build_id'],
        'known_message_sha3_comparisons':34,'functional_batches':16,'assessment_batches':1000,
        'all_1016_saved_batch_digests_recomputed_and_matched':True,
        'payload_samples_assessed':1024000,'conditioned_bytes_in_assessment_collection':32000,
        'health_faults_in_saved_successful_batches':0,'ro_off_at_end':True,'both_dma_halted_at_end':True,
        'non_iid_assessments_completed':9,'ro_restart_tests_passed':9,
        'initial_joint_statistical_estimate':joint['initial_statistical_estimate'],
        'retained_joint_statistical_estimate':joint['retained_statistical_estimate'],
        'previous_health_only_retained_joint_estimate':previous['retained_joint_statistical_estimate'],
        'lowest_retained_channel_estimate':min(x['retained_statistical_estimate'] for x in channels),
        'monitor_design_assumption_per_channel':0.5,
        'this_dataset_estimates_exceed_monitor_assumption':all(x['retained_statistical_estimate']>0.5 for x in channels),
        'capture_plus_hash_seconds_mean_excluding_file_writes':sum(elapsed)/len(elapsed),
        'performance_note':'Python monotonic timing covers capture+readback+FPGA hash+comparison; not isolated SHA3 throughput or power measurement.',
        'board_clock_note':integrity['clock_note'],
        'scope':'One board, one build, one reported session; RO enable-cycle restarts after startup discard, not board power-cycle tests.',
        'physical_fault_injection_performed':False,'validated_entropy_credit':None,'entropy_certified':False,
        'remaining':['Physical/source-model and temporal-dependence entropy-credit justification','Compression/output-budget justification','Stability over the environmental and board conditions chosen for the research scope','Low-power and performance evaluation if claimed'],
        'assessments':restarts,
        'tool_provenance':json.loads((OUT/'nist_results/tool_provenance.json').read_text()),
    }
    (OUT/'assessment_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    acceptance={k:summary[k] for k in ['experiment_date','board_id','build_id','known_message_sha3_comparisons','functional_batches','assessment_batches','all_1016_saved_batch_digests_recomputed_and_matched','ro_off_at_end','both_dma_halted_at_end','retained_joint_statistical_estimate','validated_entropy_credit','entropy_certified']}
    acceptance['status']='PASS';acceptance['evidence']='captures/board_21600/integrated_20261116/assessment_summary.json'
    (ROOT/'build/board_acceptance_20261116.json').write_text(json.dumps(acceptance,indent=2)+'\n')
    rows='\n'.join('| {} | {:.6f} | {:.6f} |'.format(x['label'],x['initial_statistical_estimate'],x['retained_statistical_estimate']) for x in [joint]+channels)
    fractions='、'.join('{}: {:.3%}'.format(x['channel'],x['ones_fraction']) for x in stats['channels'])
    text=f'''# SHA3 整合版實板驗收與原始資料評估

實驗日期（使用者填寫）：2026-11-16；板號：21600；版本：`{summary['build_id']}`。

**本階段 SHA3 功能整合已通過實板驗收。**健康熵源、處理器搬運、FPGA SHA3、DMA 回傳及 Python 比對已在同一份電路上完成。這是可運作的 TRNG 研究原型，不是正式熵信用或認證結論。

## 實際完成的核對

- 原始兩份 ZIP 與執行過的 Notebook 原封不動保存，指紋列於 `integrity_review.json`。
- Notebook 八個程式格都有執行結果，沒有保存的 exception；原始碼與發布操作本相比只有板號／日期紀錄格不同，未執行附件內程式。
- 34 次已知訊息 SHA3 比對通過，包含空訊息、abc、136-byte 邊界及長訊息。
- 16 批驗收與 1000 批收集均完成。共 1016 批保存的摘要，已在本機再次對 raw 重算 SHA3，全部一致。
- 每批健康狀態符合 status=194、count=1024、observed=2048、startup_seen=1024、所有故障遮罩=0、RO 關閉。
- 兩份集合各自沒有重複的完整 raw 批次或 digest；1000 批集合沒有重複的前 32-byte raw 前綴。
- Notebook 最後確認 RO 關閉，兩個 DMA 通道均 Halted。這次沒有在實體 FPGA 注入故障，不能把先前模擬注入案例稱為實板故障實驗。

## 新布局的 NIST 工具輸出

只評估 **SHA3 前的原始資料**：1000 批 × 1024 八路樣本 = 1,024,000 個樣本；每個樣本用一 byte 記錄八路。另取每批前 1000 個保留樣本形成 1000×1000 重啟矩陣。

使用先前核對的相同 NIST 執行檔與版本，二進位指紋一致；沿用其 11 組官方非 IID 自測與正／負重啟控制的驗證紀錄。Windows 重啟工具的移植範圍與來源版本保留在 `nist_results/tool_provenance.json`。

九組非 IID（不假設每個樣本互相獨立且同分布）估計皆完成，九組 RO 重啟評估皆通過。保留值取工具列出的 min(H_I,H_r,H_c)，沒有挑選最高結果。

| 資料 | 初始估計 | 綜合保留估計 |
|---|---:|---:|
{rows}

joint 的單位是 **bits／八路樣本**，channel 的單位是 bits／該路單一樣本；不可將八路估計相加當作 joint 熵。

本次 joint 的 H_r={joint['restart_H_r']:.6f}、H_c={joint['restart_H_c']:.6f}，因此保留值為 **{joint['retained_statistical_estimate']:.6f} bits／八路樣本**。

與 stage3 保留值 {previous['retained_joint_statistical_estimate']:.6f} 相比，本次數字較高；但初始 joint 估計從舊 {previous['initial_joint_statistical_estimate']:.6f} 變成新 {joint['initial_statistical_estimate']:.6f}，並不是每一項指標都改善。舊版主要由重啟欄向估計拉低，本次由初始估計決定。兩次不是同時、同環境的受控對照，不能推論 SHA3 提高了物理熵。

## 仍保留的不完美現象

各路「1」比例：{fractions}。其中第 1 路約 53.17%，有可見偏置。第 5～7 路仍有批內時間相關；第 5 路 lag-1 平均約 -0.0309，第 6／7 路各批絕對相關的第 95 百分位約 0.108／0.110。完整結果列於 `descriptive_review.json`，未刪除較差批次。

最低單路保留估計為 {summary['lowest_retained_channel_estimate']:.6f}，高於健康門檻設計採用的 0.5 bits 假設。這只是本資料集的統計支持，**不是**已驗證的物理熵下界。健康檢查通過本身不證明不可預測。

板上檔名時間早於發布版本時間，與使用者填寫的實驗日期不一致；保留原始檔名，以填寫日期記錄此次實驗，不以板上時鐘證明時間順序。

## 結論與下一階段

SHA3 功能整合、正常資料端到端運行，以及本次新布局的有限原始資料評估已完成。每批以 1024 bytes 原始資料產生 32 bytes 摘要，並逐批核對計算功能。

尚不能把 1024×{joint['retained_statistical_estimate']:.6f} 直接當作保證輸入熵，或把 256-bit 摘要稱為已保證 256 bits 真實熵。還需要原始物理機制與跨時間依賴的熵信用論證、輸出量／壓縮比例依據，以及研究聲稱涵蓋的溫壓／板卡／運行條件驗證。若要主張低功耗，另外量測功耗、成本與吞吐量。

這裡的 restart 是 RO 啟停並丟棄啟動資料，不是整張板子的斷電開機測試。此版本由 PS 程式搬運與把關，不是全自動 RO→SHA3 硬體串流。

不需要為了修正這次功能流程而重做 Vivado 或更換 bitstream；本次沒有發現需修改上板檔的功能錯誤。
'''
    (OUT/'REVIEW.md').write_text(text,encoding='utf-8')
    print(json.dumps(acceptance,indent=2))
if __name__=='__main__':main()
