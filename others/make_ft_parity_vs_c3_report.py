# -*- coding: utf-8 -*-
"""Parity + Replay vs C3 / lane SECDED, 10 ns only."""

from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether,
)

OUT = Path(__file__).with_name("SHA3_FT_parity_vs_C3_10ns_report.pdf")
FONT = r"C:\Windows\Fonts\msjh.ttc"

pdfmetrics.registerFont(TTFont("CJ", FONT, subfontIndex=0))

NAVY = HexColor("#1F3A5F")
TEAL = HexColor("#2F6F6A")
LINE = HexColor("#D5DAE0")
ROW_ALT = HexColor("#F7F8FA")
LIGHT = HexColor("#E8EEF6")
GREEN = HexColor("#1B7A4E")
RED = HexColor("#B42318")
MUTED = HexColor("#5B6570")

# release1 / phase1-lane-serial-energy @ 10 ns
C3 = dict(area=43698.68854, static=0.2768897, dyn=1.6115, tot=1.8883897,
          tp=0.453333333, e=4.16556552, slack=1.46)

LANE = dict(area=87513.498982, static=0.5613525, dyn=2.852, tot=3.4133525,
            tp=0.453333333, e=7.52945405, slack=0.34)

# workstation sweep 10 ns, FT_ENABLE=1, SHA3_parity
PAR = dict(area=63337.3, static=0.400271, dyn=2.0556, tot=2.455871,
           tp=0.453333, e=5.417363, slack=1.33)


def pct(a, b):
    return (b - a) / a * 100.0


def fnum(v, d=3):
    s = f"{v:.{d}f}"
    return s.rstrip("0").rstrip(".") if "." in s else s


def signed_pct(v):
    return f"{v:+.1f}%"


def hexcol(c):
    return "#%02X%02X%02X" % (int(c.red * 255), int(c.green * 255), int(c.blue * 255))


def color_for(delta, higher_better):
    if abs(delta) < 0.15:
        return NAVY
    better = (delta > 0) if higher_better else (delta < 0)
    return GREEN if better else RED


def styles():
    base = getSampleStyleSheet()
    kw = dict(fontName="CJ", wordWrap="CJK", alignment=TA_LEFT, textColor=NAVY)
    return {
        "h1": ParagraphStyle("h1", parent=base["Title"], fontName="CJ", fontSize=15,
                             leading=21, spaceAfter=6, **{k: kw[k] for k in ("wordWrap", "alignment", "textColor")}),
        "h2": ParagraphStyle("h2", parent=base["Heading2"], fontName="CJ", fontSize=12,
                             leading=17, spaceBefore=10, spaceAfter=5, textColor=TEAL, wordWrap="CJK"),
        "p": ParagraphStyle("p", parent=base["BodyText"], fontSize=9.2, leading=14,
                            spaceAfter=4, **kw),
        "note": ParagraphStyle("note", parent=base["BodyText"], fontName="CJ", fontSize=8,
                               leading=12, textColor=MUTED, wordWrap="CJK"),
        "th": ParagraphStyle("th", fontName="CJ", fontSize=8, leading=11,
                             textColor=HexColor("#FFFFFF"), wordWrap="CJK"),
        "td": ParagraphStyle("td", fontName="CJ", fontSize=8, leading=11,
                             textColor=NAVY, wordWrap="CJK"),
        "tdb": ParagraphStyle("tdb", fontName="CJ", fontSize=8, leading=11,
                              textColor=NAVY, wordWrap="CJK"),
        "cap": ParagraphStyle("cap", fontName="CJ", fontSize=7.5, leading=11,
                              textColor=MUTED, wordWrap="CJK", spaceBefore=2, spaceAfter=8),
    }


def P(text, st):
    return Paragraph(text, st)


def main_table(st, w):
    rows_def = [
        ("面積 (µm²)", "area", 1, False),
        ("靜態 (mW)", "static", 3, False),
        ("動態 (mW)", "dyn", 3, False),
        ("總功耗 (mW)", "tot", 3, False),
        ("吞吐 (Gbps)", "tp", 3, True),
        ("E/bit (pJ/bit)", "e", 3, False),
        ("Slack (ns)", "slack", 2, True),
    ]
    head = [P(x, st["th"]) for x in
            ["指標", "Release1 (C3)", "Lane SECDED", "Parity+Replay", "Parity vs C3", "Parity vs SECDED"]]
    data = [head]
    for name, key, digits, higher_better in rows_def:
        c3, la, pa = C3[key], LANE[key], PAR[key]
        d1, d2 = pct(c3, pa), pct(la, pa)
        c1, c2 = color_for(d1, higher_better), color_for(d2, higher_better)
        data.append([
            P(name, st["tdb"]),
            P(fnum(c3, digits), st["td"]),
            P(fnum(la, digits), st["td"]),
            P(fnum(pa, digits), st["td"]),
            P(f'<font color="{hexcol(c1)}">{signed_pct(d1)}</font>', st["td"]),
            P(f'<font color="{hexcol(c2)}">{signed_pct(d2)}</font>', st["td"]),
        ])
    t = Table(data, colWidths=w, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.5),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("GRID", (0, 0), (-1, -1), 0.3, LINE),
        ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
        ("ALIGN", (0, 1), (0, -1), "LEFT"),
    ]
    for i in range(2, len(data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), ROW_ALT))
    t.setStyle(TableStyle(cmds))
    return t


def lit_table(st, w):
    head = [P(x, st["th"]) for x in ["文獻 / 做法", "保護能力", "文獻回報代價", "能不能直接對照", "和我們比"]]
    rows = [
        ("RERO（時間重算，detect）",
         "只偵測。無故障也幾乎都做第二次旋轉複算；要恢復通常整段重來",
         "面積 +4–8%",
         "不能直接比面積％（65 nm、一 round 一拍的大核）",
         "面積％我們較高，不代表比較弱：對方沒有局部恢復、沒故障也要付第二次運算。我們無故障吞吐不變，偵到才重算當前 5 個 lane。"),
        ("Ewert z-sheet / c-plane parity",
         "多半只偵測；切面奇偶，偶數錯仍可能漏",
         "面積約 +56%",
         "只能比開銷量級與保護類型，不能比 pJ",
         "同類奇偶。我們 +44.9% 略低，且多了整欄／列 replay。兩邊都不是 SECDED。"),
        ("ArchHC（整顆 1600 Hamming，FPGA）",
         "1-bit 修正",
         "LUT 約 12×；吞吐約保留 98%",
         "不能比面積％（FPGA LUT vs 40 nm cell）",
         "功能對方較強（能當拍翻 bit）。我們已不做修正，不能說功能等價。"),
        ("Impeccable SoC 類",
         "強防護（系統級完整性）",
         "面積約 3.2×",
         "不能直接對照（防護範圍不是同一顆 SHA-3 核）",
         "只說明量級：我們 1.45× 便宜很多，防護也窄很多。"),
        ("本組上一版 Lane SECDED",
         "1-bit 當拍修正，2-bit replay",
         "面積 +100.3%，E +80.8%",
         "可以（同一 40 nm、10 ns、同一 C3）",
         "這版面積 +44.9%、E +30.1%。PPA 較好；功能拿掉當拍修正，改成較瘦的偵測＋局部重算。"),
    ]
    data = [head]
    for a, b, c, d, e in rows:
        data.append([P(a, st["td"]), P(b, st["td"]), P(c, st["td"]), P(d, st["td"]), P(e, st["td"])])
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
    canvas.drawString(18 * mm, 10 * mm,
                      "SHA-3 Candidate 3　Parity+Replay vs Release1　TSMC 40 nm / 10 ns / vectorless")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"{doc.page}")
    canvas.restoreState()


def build():
    st = styles()
    story = []
    w = [28 * mm, 28 * mm, 28 * mm, 28 * mm, 27 * mm, 27 * mm]
    wlit = [32 * mm, 30 * mm, 28 * mm, 32 * mm, 44 * mm]

    story.append(P("SHA-3 容錯：代數奇偶預測 + Replay（10 ns 主測）", st["h1"]))

    story.append(P("一、數字先看", st["h2"]))
    story.append(P(
        f"相對無容錯 C3：面積 {signed_pct(pct(C3['area'], PAR['area']))}（{fnum(C3['area'], 0)} → {fnum(PAR['area'], 1)} µm²），"
        f"總功耗與 E/bit {signed_pct(pct(C3['e'], PAR['e']))}（{fnum(C3['e'], 3)} → {fnum(PAR['e'], 3)} pJ/bit），"
        f"吞吐仍 0.453 Gbps，slack {fnum(PAR['slack'], 2)} ns。"
        f"相對上一版 Lane SECDED：面積 {signed_pct(pct(LANE['area'], PAR['area']))}、"
        f"E {signed_pct(pct(LANE['e'], PAR['e']))}。",
        st["p"]))

    story.append(KeepTogether([
        P("二、10 ns 主表（對 release1）", st["h2"]),
        P(
            "C3 數字與上次給老師的 10 ns 表同一列：面積 43699 µm²、1.888 mW、4.166 pJ/bit、slack 1.46 ns。"
            "Parity 為本次工作站 FT_ENABLE=1、status=OK 的單點。",
            st["p"]),
        main_table(st, w),
        P(
            "表 1　綠色＝該欄相對比較對象較好。吞吐三版相同，因為 cycle 與 period 都沒變。"
            "Parity 的 slack 1.33 ns 接近 C3 的 1.46，代表拿掉 Hamming 樹後關鍵路徑鬆回來。",
            st["cap"]),
    ]))

    story.append(P("三、功能分析（這版在防什麼、防不到什麼）", st["h2"]))
    story.append(P(
        "這版不是 SECDED。寫入前用獨立預測器從運算前輸入算出每個 active lane 的偶校驗，"
        "和實際輸出 XOR-reduction 比較。任一 active lane 失配，或 θ 的 C checkpoint 失配："
        "整欄（θ）或整列（χ）不提交，索引 hold，下一拍用原輸入 replay。通過才前進。"
        "沒有當拍翻 bit，沒有 CORRECTED／UNCORR 分類。",
        st["p"]))
    story.append(P(
        "抓得到：單一 lane 上任意奇數個翻轉；兩個不同 lane 各一 bit（各有自己的 checker）；"
        "C 計算後、checkpoint 前的 C 注入。抓不到：同一 lane 偶數個翻轉（校驗互消），"
        "TB 有兩案是預期漏偵測且 digest 錯誤。共享輸入／frozen 快照先壞、預測與資料一齊錯，也會漏。"
        "永久故障會停在 replay，不會放行未驗證 digest。無故障仍是 240 運算拍；每偵到一次失敗多 1 拍。",
        st["p"]))
    story.append(P(
        "RTL 模擬（組員紀錄，非正式工作站 VCS）：18 個 SHA3-256 功能案通過；"
        "153 個 parity／replay 案通過（含上述兩個漏偵測特性案）。"
        "尚未做 gate-level 注入。合成將注入埠 set_case_analysis 0。",
        st["p"]))

    story.append(P("四、和上次同一批文獻比", st["h2"]))
    story.append(P(
        "論文集合與上次給老師的表相同：RERO、Ewert、ArchHC、Impeccable，外加本組 SECDED。"
        "多數不能直接對照面積％或 pJ，仍列出來標明「不能比什麼」。"
        "對得上的只有同一顆 40 nm 核上的 SECDED。",
        st["p"]))
    story.append(P(
        "面積或能量輸了，不代表這版比較弱。RERO 開銷更低，是因為它只偵測、而且沒故障也幾乎要做第二次運算；"
        "我們多付的面積，換的是無故障吞吐不變，以及偵到錯誤時只重算當前欄／列、讓暫時故障有機會恢復。"
        "功能比較完整但 PPA 數字較差，是不同設計取捨，不是同一條尺上的落敗。",
        st["p"]))
    story.append(lit_table(st, wlit))
    story.append(P("表 2　與上次相同的文獻集合。最後一列才是可直接比的 PPA。", st["cap"]))

    story.append(P("五、結論：有沒有競爭力", st["h2"]))
    story.append(P(
        "在「低功耗 SHA-3 + 偵測與局部恢復、無故障吞吐不掉」這條線上有競爭力："
        "相對 C3 面積 +45%、能量 +30%，比本組 SECDED 瘦，和 Ewert 同類奇偶相比開銷也不差，而且多了局部 replay。",
        st["p"]))
    story.append(P(
        "若把賽道設成「面積開銷最小」或「能當拍修 1-bit」，數字會輸。RERO +4–8% 我們比不了，但對方功能較薄；"
        "ArchHC 能翻 bit，我們不做，面積％也不能比。"
        "輸在開銷、贏在功能完整度時，應分開寫，不要讀成全面弱勢。老師要的 ≤15% 尚未達到。",
        st["p"]))
    story.append(P(
        "C3／SECDED：既有 10 ns 合成。Parity：本次 FT_ENABLE=1、status=OK。"
        "文獻代價沿用上次報告（RERO +4–8%、Ewert ~+56%、Impeccable ~3.2×、ArchHC FPGA LUT ~12×）。",
        st["note"]))

    doc = SimpleDocTemplate(
        str(OUT), pagesize=A4,
        leftMargin=16 * mm, rightMargin=16 * mm,
        topMargin=14 * mm, bottomMargin=16 * mm,
        title="SHA-3 FT Parity vs C3 10 ns",
        author="SHA3 undergraduate research",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
