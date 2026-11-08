#!/usr/bin/env python3
"""まとめMarkdown（JRA結果まとめ_YYYY-MM-DD.md）をアプリ用JSONに変換する。

使い方:
  python3 convert.py <input.md> <output_dir>
出力:
  <output_dir>/<date>.json  その日の全レースデータ
  <output_dir>/index.json   日付一覧（既存分とマージ）
"""
import json
import re
import sys
from pathlib import Path

CIRCLED = "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳"
HORSE_RE = re.compile(
    r"^-\s*(?:(?P<finish>\d+)着|(?P<dnf>中止))\s*(?P<number>[0-9]+|[" + CIRCLED + r"])\s*(?P<name>[^\s（]+)"
    r"(?:（(?P<pop>\d+)人気）)?\s*(?P<jockey>[^\s]+)\s+通過(?P<passing>\S+)\s+上がり(?P<last3f>\S+)"
    r"(?:\s+—\s*(?P<comment>.*))?$"
)


def horse_number(token: str) -> int:
    if token.isdigit():
        return int(token)
    return CIRCLED.index(token) + 1
RACE_HEAD_RE = re.compile(
    r"^##\s+(?P<venue>[^\d\s]+)(?P<num>\d+)R\s+(?P<name>.+?)（(?P<cond>[^）]*)）\s*$"
)
COND_RE = re.compile(r"(芝|ダート|障害)[^\d]*(?P<dist>\d+)\s*m")


def parse(text: str) -> dict:
    date_m = re.search(r"(\d{4})年(\d{1,2})月(\d{1,2})日", text)
    date = None
    if date_m:
        date = f"{int(date_m.group(1)):04d}-{int(date_m.group(2)):02d}-{int(date_m.group(3)):02d}"

    summary = []
    in_summary = False
    races = []
    cur = None
    in_horses = False

    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("## 総括"):
            in_summary = True
            continue
        if line.startswith("## ") or line.startswith("# "):
            in_summary = False
            in_horses = False
            m = RACE_HEAD_RE.match(line)
            if m:
                cond = m.group("cond")
                cm = COND_RE.search(cond)
                cur = {
                    "venue": m.group("venue") + "競馬場",
                    "raceNumber": int(m.group("num")),
                    "raceName": m.group("name"),
                    "surface": cm.group(1) if cm else cond,
                    "distance": int(cm.group("dist")) if cm else 0,
                    "courseTrait": "",
                    "raceFlow": "",
                    "winnerStyle": "",
                    "horses": [],
                }
                races.append(cur)
            else:
                cur = None
            continue
        if in_summary and line.startswith("- "):
            summary.append(line[2:].strip())
            continue
        if cur is None:
            continue
        if line.startswith("- コース特徴:"):
            cur["courseTrait"] = line.split(":", 1)[1].strip()
        elif line.startswith("- レースの運び:"):
            cur["raceFlow"] = line.split(":", 1)[1].strip()
        elif line.startswith("- 勝ち馬の型:"):
            cur["winnerStyle"] = line.split(":", 1)[1].strip()
        elif line.startswith("- 全馬結果"):
            in_horses = True
        elif in_horses and line.startswith("- "):
            body = line[2:].strip()
            hm = HORSE_RE.match("- " + body) if False else HORSE_RE.match("- " + body)
            if hm:
                cur["horses"].append(
                    {
                        "finish": hm.group("finish") or "中止",
                        "number": horse_number(hm.group("number")),
                        "name": hm.group("name"),
                        "popularity": int(hm.group("pop")) if hm.group("pop") else None,
                        "jockey": hm.group("jockey"),
                        "passing": hm.group("passing"),
                        "last3f": hm.group("last3f"),
                        "comment": (hm.group("comment") or "").strip(),
                    }
                )
    return {"date": date, "summary": summary, "races": races}


def main() -> None:
    src = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    data = parse(src.read_text(encoding="utf-8"))
    if not data["date"]:
        raise SystemExit("日付が見つかりませんでした")
    day_file = out_dir / f"{data['date']}.json"
    day_file.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    index_file = out_dir / "index.json"
    days = []
    if index_file.exists():
        days = json.loads(index_file.read_text(encoding="utf-8")).get("days", [])
    days = [d for d in days if d != data["date"]] + [data["date"]]
    days.sort(reverse=True)
    index_file.write_text(
        json.dumps({"days": days}, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    n_horses = sum(len(r["horses"]) for r in data["races"])
    print(f"{data['date']}: {len(data['races'])} races, {n_horses} horses -> {day_file}")


if __name__ == "__main__":
    main()
