# -*- coding: utf-8 -*-
"""Lane Hamming vs 1600 Hamming sweep report (PDF)."""

from pathlib import Path

from reportlab.lib.colors import HexColor, Color
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether,
)

OUT = Path(__file__).with_name("SHA3_FT_lane_vs_1600_sweep_report.pdf")
FONT = r"C:\Windows\Fonts\msjh.ttc"
FONT_BD = r"C:\Windows\Fonts\msjhbd.ttc"

pdfmetrics.registerFont(TTFont("CJ", FONT, subfontIndex=0))
pdfmetrics.registerFont(TTFont("CJBd", FONT_BD, subfontIndex=0))

NAVY = HexColor("#1F3A5F")
TEAL = HexColor("#2F6F6A")
LINE = HexColor("#D5DAE0")
GRAY_BG = HexColor("#F2F3F5")
ROW_ALT = HexColor("#F7F8FA")
LIGHT = HexColor("#E8EEF6")
GREEN = HexColor("#1B7A4E")
RED = HexColor("#B42318")
MUTED = HexColor("#5B6570")

# C3 no-FT @ 10 ns (advisor table / sweep_summary baseline)
C3 = dict(area=43698.68854, static=0.2768897, dyn=1.6115, tot=1.8883897,
          tp=0.453333333, e=4.16556552, slack=1.46, period=10.0)

# Lane FT sweep (Downloads/sweep_summary.csv, OK rows)
LANE10 = dict(area=87513.498982, static=0.5613525, dyn=2.852, tot=3.4133525,
              tp=0.453333333, e=7.52945405, slack=0.34, period=10.0)
LANE_EMIN = dict(area=94851.613294, static=0.7700665, dyn=8.3055, tot=9.0755665,
                 tp=1.2952381, e=7.00687117, slack=0.00, period=3.5)
LANE_PMIN = dict(area=149955.621901, static=2.1131, dyn=19.8068, tot=21.9199,
                 tp=2.51851852, e=8.7034897, slack=0.00, period=1.8)

# 1600 FT sweep (Downloads/sweep_summary1600.csv, OK rows)
S1610 = dict(area=89176.850420, static=0.6098809, dyn=2.9578, tot=3.5676809,
             tp=0.453333333, e=7.86988434, slack=0.00, period=10.0)
S16_EMIN = dict(area=93475.390892, static=0.7367325, dyn=7.5073, tot=8.2440325,
                tp=1.13333333, e=7.27414634, slack=0.00, period=4.0)
S16_PMIN = dict(area=137317.645625, static=1.8295, dyn=15.9295, tot=17.759,
                tp=1.97101449, e=9.01008089, slack=0.00, period=2.3)


def pct(a, b):
    return (b - a) / a * 100.0


def fnum(v, d=3):
    if isinstance(v, int):
        return str(v)
    s = f"{v:.{d}f}"
    return s.rstrip("0").rstrip(".") if "." in s else s


def signed_pct(v):
    return f"{v:+.1f}%"


def styles():
    base = getSampleStyleSheet()
    kw = dict(fontName="CJ", wordWrap="CJK", alignment=TA_LEFT, textColor=NAVY)
    return {
        "h1": ParagraphStyle("h1", parent=base["Title"], fontName="CJBd", fontSize=16,
                             leading=22, spaceAfter=6, **{k: kw[k] for k in ("wordWrap", "alignment", "textColor")}),
        "h2": ParagraphStyle("h2", parent=base["Heading2"], fontName="CJBd", fontSize=12,
                             leading=17, spaceBefore=10, spaceAfter=5, textColor=TEAL, wordWrap="CJK"),
        "h3": ParagraphStyle("h3", parent=base["Heading3"], fontName="CJBd", fontSize=10.5,
                             leading=15, spaceBefore=7, spaceAfter=3, textColor=NAVY, wordWrap="CJK"),
        "p": ParagraphStyle("p", parent=base["BodyText"], fontSize=9.2, leading=14,
                            spaceAfter=4, **kw),
        "note": ParagraphStyle("note", parent=base["BodyText"], fontName="CJ", fontSize=8,
                               leading=12, textColor=MUTED, wordWrap="CJK"),
        "th": ParagraphStyle("th", fontName="CJBd", fontSize=8, leading=11,
                             textColor=HexColor("#FFFFFF"), wordWrap="CJK"),
        "td": ParagraphStyle("td", fontName="CJ", fontSize=8, leading=11,
                             textColor=NAVY, wordWrap="CJK"),
        "tdb": ParagraphStyle("tdb", fontName="CJBd", fontSize=8, leading=11,
                              textColor=NAVY, wordWrap="CJK"),
        "cap": ParagraphStyle("cap", fontName="CJ", fontSize=7.5, leading=11,
                              textColor=MUTED, wordWrap="CJK", spaceBefore=2, spaceAfter=8),
    }


def P(text, st):
    return Paragraph(text, st)


def hexcol(c):
    return "#%02X%02X%02X" % (int(c.red * 255), int(c.green * 255), int(c.blue * 255))


def color_for(delta, higher_better):
    if abs(delta) < 0.15:
        return NAVY
    better = (delta > 0) if higher_better else (delta < 0)
    return GREEN if better else RED


def metric_table(st, rows, col_w):
    head = [P(x, st["th"]) for x in ["指標", "Lane Hamming", "1600 Hamming", "1600 相對 lane", "註"]]
    data = [head]
    for name, a, b, higher_better, note, fmt_a, fmt_b in rows:
        d = pct(a, b)
        c = color_for(d, higher_better)
        data.append([
            P(name, st["tdb"]),
            P(fmt_a, st["td"]),
            P(fmt_b, st["td"]),
            P(f'<font color="{hexcol(c)}">{signed_pct(d)}</font>', st["td"]),
            P(note, st["td"]),
        ])
    t = Table(data, colWidths=col_w, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
        ("ALIGN", (1, 1), (3, -1), "RIGHT"),
    ]
    for i in range(2, len(data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), ROW_ALT))
    t.setStyle(TableStyle(cmds))
    return t


def pair_rows(la, s16):
    return [
        ("週期 (ns)", la["period"], s16["period"], False, "愈短愈快",
         f'{fnum(la["period"], 1)}', f'{fnum(s16["period"], 1)}'),
        ("面積 (µm²)", la["area"], s16["area"], False, "愈小愈好",
         f'{fnum(la["area"], 2)}', f'{fnum(s16["area"], 2)}'),
        ("靜態 (mW)", la["static"], s16["static"], False, "愈小愈好",
         f'{fnum(la["static"], 3)}', f'{fnum(s16["static"], 3)}'),
        ("動態 (mW)", la["dyn"], s16["dyn"], False, "愈小愈好",
         f'{fnum(la["dyn"], 3)}', f'{fnum(s16["dyn"], 3)}'),
        ("總功耗 (mW)", la["tot"], s16["tot"], False, "愈小愈好",
         f'{fnum(la["tot"], 3)}', f'{fnum(s16["tot"], 3)}'),
        ("吞吐 (Gbps)", la["tp"], s16["tp"], True, "愈大愈好",
         f'{fnum(la["tp"], 3)}', f'{fnum(s16["tp"], 3)}'),
        ("E/bit (pJ/bit)", la["e"], s16["e"], False, "愈小愈好",
         f'{fnum(la["e"], 3)}', f'{fnum(s16["e"], 3)}'),
        ("Slack (ns)", la["slack"] + 1e-9, s16["slack"] + 1e-9, True, "愈大愈好；皆 MET",
         f'{fnum(la["slack"], 2)}', f'{fnum(s16["slack"], 2)}'),
    ]


def three_col_10ns(st, w):
    rows_def = [
        ("面積 (µm²)", "area", 2, False),
        ("靜態 (mW)", "static", 3, False),
        ("動態 (mW)", "dyn", 3, False),
        ("總功耗 (mW)", "tot", 3, False),
        ("吞吐 (Gbps)", "tp", 3, True),
        ("E/bit (pJ/bit)", "e", 3, False),
        ("Slack (ns)", "slack", 2, True),
    ]
    head = [P(x, st["th"]) for x in
            ["指標", "無 FT (C3)", "Lane Hamming", "1600 Hamming", "Lane vs C3", "1600 vs C3"]]
    data = [head]
    for name, key, digits, higher_better in rows_def:
        c3, la, s16 = C3[key], LANE10[key], S1610[key]
        d1, d2 = pct(c3, la), pct(c3, s16)
        c1, c2 = color_for(d1, higher_better), color_for(d2, higher_better)
        data.append([
            P(name, st["tdb"]),
            P(fnum(c3, digits), st["td"]),
            P(fnum(la, digits), st["td"]),
            P(fnum(s16, digits), st["td"]),
            P(f'<font color="{hexcol(c1)}">{signed_pct(d1)}</font>', st["td"]),
            P(f'<font color="{hexcol(c2)}">{signed_pct(d2)}</font>', st["td"]),
        ])
    t = Table(data, colWidths=w, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.5),
        ("TOPPADDING", (0, 0), (-1, -1), 3.2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.2),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
        ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
    ]
    for i in range(1, len(data)):
        cmds.append(("BACKGROUND", (0, i), (-1, i), LIGHT if i == 1 else (ROW_ALT if i % 2 == 0 else Color(1, 1, 1))))
    t.setStyle(TableStyle(cmds))
    return t


def lit_table(st, w):
    head = [P(x, st["th"]) for x in ["文獻 / 做法", "保護能力", "文獻回報代價", "和我們比"]]
    rows = [
        ("ArchHC（整顆 1600 Hamming，FPGA）",
         "1-bit 修正",
         "LUT 約 12×；吞吐約保留 98%",
         "我們 ASIC 面積約 2.0×，遠低於其 FPGA 面積比；但它是修正類，能力接近"),
        ("RERO（時間重算，detect）",
         "只偵測",
         "面積 +4–8%",
         "我們面積高很多，但我們能修 1-bit、2-bit 還能 replay"),
        ("Ewert z-sheet parity",
         "多半只偵測",
         "面積約 +56%",
         "我們面積仍較高，換到的是 SECDED + 選擇性 replay"),
        ("Impeccable SoC 類",
         "強防護",
         "面積約 3.2×",
         "我們約 2.0×，代價較低"),
        ("本工作 lane Hamming",
         "SECDED + 選擇性 replay",
         "10 ns：面積 +100%、E +81%（相對無 FT）",
         "主方案；與 C3 同一套 240 cycle、vectorless"),
        ("本工作 1600 Hamming",
         "同一套 FT 功能",
         "10 ns：面積 +104%、E +89%（相對無 FT）",
         "對照組；沒有比 lane 省"),
    ]
    data = [head]
    for a, b, c, d in rows:
        data.append([P(a, st["td"]), P(b, st["td"]), P(c, st["td"]), P(d, st["td"])])
    t = Table(data, colWidths=w, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), ROW_ALT))
        if i == 5:
            cmds.append(("BACKGROUND", (0, i), (-1, i), LIGHT))
    t.setStyle(TableStyle(cmds))
    return t


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("CJ", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, "SHA-3 Candidate 3　lane Hamming vs 1600 Hamming　TSMC 40 nm / vectorless")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"{doc.page}")
    canvas.restoreState()


def build():
    st = styles()
    story = []
    w = [32 * mm, 32 * mm, 32 * mm, 28 * mm, 42 * mm]
    w3 = [28 * mm, 26 * mm, 28 * mm, 28 * mm, 22 * mm, 22 * mm]
    wlit = [38 * mm, 28 * mm, 42 * mm, 58 * mm]

    story.append(P("SHA-3 容錯：Lane Hamming 與 1600-bit Hamming 掃頻比較", st["h1"]))
    story.append(P(
        "同一套 Candidate 3（一拍最多 5 lane、10 cycle/round、240 cycle/block）、"
        "同一套 SECDED + 選擇性 replay。差別只有 state Hamming 粒度："
        "25×(72,64) 對 1×(1612,1600)。TSMC 40 nm sc9 RVT，tt 0.9 V 25°C，compile_ultra，vectorless。"
        "百分比＝（1600 − lane）／ lane。吞吐與 slack 愈大愈好，其餘愈小愈好。",
        st["p"]))

    story.append(P("一、三個比較點（請從這裡看）", st["h2"]))
    story.append(P(
        "結論先講：在公平對照下，1600 沒有比較省。10 ns 面積 +1.9%、E/bit +4.5%；"
        "最低 E/bit 仍是 lane 較低；最低可過週期 lane 1.8 ns、1600 2.3 ns（lane 可多跑約 28% 頻率）。"
        "不要把 1600 再切 pipeline 去遷就短週期，那會破壞同一套 C3。",
        st["p"]))

    # summary strip
    fmax_l, fmax_s = 1000.0 / 1.8, 1000.0 / 2.3
    summary = [
        [P(x, st["th"]) for x in ["比較點", "Lane", "1600", "解讀"]],
        [P("論文主測 10 ns", st["tdb"]),
         P(f'E {fnum(LANE10["e"], 3)}　slack {fnum(LANE10["slack"], 2)}', st["td"]),
         P(f'E {fnum(S1610["e"], 3)}　slack {fnum(S1610["slack"], 2)}', st["td"]),
         P(f'面積 {signed_pct(pct(LANE10["area"], S1610["area"]))}，E {signed_pct(pct(LANE10["e"], S1610["e"]))}。同量級，lane 略好、slack 較鬆。', st["td"])],
        [P("最低 E/bit 週期", st["tdb"]),
         P(f'{fnum(LANE_EMIN["period"], 1)} ns　E {fnum(LANE_EMIN["e"], 3)}', st["td"]),
         P(f'{fnum(S16_EMIN["period"], 1)} ns　E {fnum(S16_EMIN["e"], 3)}', st["td"]),
         P(f'各取自己最好的 E。1600 的最佳 E 仍比 lane 高 {signed_pct(pct(LANE_EMIN["e"], S16_EMIN["e"]))}。', st["td"])],
        [P("最低可容忍週期", st["tdb"]),
         P(f'{fnum(LANE_PMIN["period"], 1)} ns　{fnum(fmax_l, 0)} MHz', st["td"]),
         P(f'{fnum(S16_PMIN["period"], 1)} ns　{fnum(fmax_s, 0)} MHz', st["td"]),
         P(f'status=OK 的最短 period。Lane Fmax 高 {signed_pct(pct(fmax_s, fmax_l))}，這是碼寬造成的 timing，不是 1600 少打 pipeline。', st["td"])],
    ]
    tsum = Table(summary, colWidths=[32 * mm, 42 * mm, 42 * mm, 50 * mm])
    tsum.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT),
        ("BACKGROUND", (0, 2), (-1, 2), ROW_ALT),
        ("BACKGROUND", (0, 3), (-1, 3), LIGHT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
    ]))
    story.append(tsum)
    story.append(P(
        "資料：lane = sweep_summary.csv（91 點，OK 至 1.8 ns）；"
        "1600 = sweep_summary1600.csv（掃到 1.9 ns，OK 至 2.3 ns）。"
        "最低可容忍週期＝status 為 OK（slack ≥ 0）的最短 clock period。",
        st["cap"]))

    story.append(KeepTogether([
        P("1. 論文主測點　10 ns", st["h3"]),
        P("兩邊吞吐相同（0.453 Gbps）。1600 的 critical path 已走到 keccak_hamming1600，slack = 0.00。", st["p"]),
        metric_table(st, pair_rows(LANE10, S1610), w),
        P("表 1　10 ns 同一週期、同一吞吐下的代價。", st["cap"]),
    ]))

    story.append(KeepTogether([
        P("2. 各設計最低 E/bit 的週期", st["h3"]),
        P("在 status=OK 的點裡，lane 最低 E 出現在 3.5 ns，1600 出現在 4.0 ns。"
          "這不是同一週期，比的是「這顆設計自己能拿到的最好能量」。", st["p"]),
        metric_table(st, pair_rows(LANE_EMIN, S16_EMIN), w),
        P("表 2　最低 E/bit 操作點。1600 的 7.7 ns 列面積/能量異常偏高，視為 DC 單點雜訊，未列入最低 E。", st["cap"]),
    ]))

    story.append(KeepTogether([
        P("3. 最低可容忍週期（Fmax）", st["h3"]),
        P("Lane 1.8 ns 仍 OK，1.7 ns 起 TIMING_FAILED。1600 2.3 ns 仍 OK，2.2 ns 起失敗。"
          "Hamming 都在「算完 → 當拍編解碼 → 寫 bank」；1600 樹較深，所以先爆。", st["p"]),
        metric_table(st, pair_rows(LANE_PMIN, S16_PMIN), w),
        P("表 3　最低可過週期。Lane 吞吐 2.519 Gbps，1600 為 1.971 Gbps（+27.8%）。", st["cap"]),
    ]))

    story.append(PageBreak())
    story.append(P("二、相對無 FT（C3）的 10 ns 主表", st["h2"]))
    story.append(P(
        "這是上次給老師的同一列 C3 數字，加上兩種 FT。"
        "吞吐三版相同，因為 cycle 數與 period 都沒變。",
        st["p"]))
    story.append(three_col_10ns(st, w3))
    story.append(P(
        "表 4　10 ns。C3：面積 43699 µm²、1.888 mW、4.166 pJ/bit、slack 1.46 ns。"
        "Lane 相對 C3 面積 +100%、E +81%；1600 相對 C3 面積 +104%、E +89%。",
        st["cap"]))
    story.append(P(
        "功耗結構（1600 @ 10 ns）：register 58%、combinational 41%、clock_network 0.76%，"
        "與 lane 版同型，沒有 ICG 那種 clock 爆炸。面積裡 combo 約 68%、seq 約 32%，"
        "符合一顆寬 Hamming 樹。",
        st["p"]))

    story.append(P("三、和文獻比代價高低", st["h2"]))
    story.append(P(
        "文獻數字平台不同（多為 FPGA 或另一套 ASIC），只能比「量級與保護能力」，不能直接比 pJ。"
        "修正類（ArchHC）我們 ASIC 面積比它的 FPGA LUT 比低很多；"
        "偵測類（RERO / Ewert）我們面積比較高，但換到修正與 replay。",
        st["p"]))
    story.append(lit_table(st, wlit))
    story.append(P("表 5　文獻代價對照。lane 與 1600 都屬「修正 + 選擇性重算」，不是 detect-only。", st["cap"]))

    story.append(P("四、名詞與測法", st["h2"]))
    gloss = [
        ("E/bit", "total_power / throughput。throughput = 1088 / (240 × period_ns) Gbps。"),
        ("vectorless", "DC report_power 不帶 SAIF。與上次 C3 報告同一套，所以三版可並排。"),
        ("最低可容忍週期", "sweep 裡 status=OK（slack ≥ 0）的最短 period。再短就 TIMING_FAILED。"),
        ("Lane Hamming", "每 64-bit lane 一顆 (72,64) SECDED；1-bit 當拍修正，2-bit 只 replay 當拍 5 lane。"),
        ("1600 Hamming", "整顆 state 一顆 (1612,1600) SECDED。θ / χ / 5-lane gating 不變；D 仍 4×(72,64)。"),
        ("公平性", "只換 Hamming 粒度。沒有為 1600 多打 pipeline。注入口合成 set_case_analysis 0。"),
    ]
    gdata = [[P("名詞", st["th"]), P("意思", st["th"])]]
    for k, v in gloss:
        gdata.append([P(k, st["tdb"]), P(v, st["td"])])
    gt = Table(gdata, colWidths=[38 * mm, 128 * mm])
    gt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT),
        ("BACKGROUND", (0, 3), (-1, 3), ROW_ALT),
        ("BACKGROUND", (0, 5), (-1, 5), ROW_ALT),
    ]))
    story.append(gt)
    story.append(Spacer(1, 6))
    story.append(P(
        "來源：[C3] 上次老師表 10 ns。[Lane FT] sweep_summary.csv，10 ns 與 Oct 4 period_10ns 報告一致"
        "（面積 87513、3.413 mW、E 7.529、slack 0.34）。"
        "[1600] sweep_summary1600.csv；10 ns 與 Oct 6 Report 一致（89177、3.568 mW、E 7.870、slack 0.00）。"
        "CSV 若出現 slack 4.4 是掃腳本誤讀，以 SHA3.timing 的 slack (MET) 為準。",
        st["note"]))

    doc = SimpleDocTemplate(
        str(OUT), pagesize=A4,
        leftMargin=16 * mm, rightMargin=16 * mm,
        topMargin=14 * mm, bottomMargin=16 * mm,
        title="SHA-3 FT lane vs 1600 Hamming",
        author="SHA3 undergraduate research",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
