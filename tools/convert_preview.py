#!/usr/bin/env python3
"""レース前展望 Markdown を アプリ用 JSON に変換する。

使い方:
    python3 tools/convert_preview.py JRAレース前展望_YYYY-MM-DD.md Data

出力:
    Data/preview-YYYY-MM-DD.json  (YYYY-MM-DD はその週の土曜)
    Data/preview-index.json       (weekends 一覧・新しい順)
"""
import json
import re
import sys
from datetime import date, timedelta
from pathlib import Path

VENUE_FORMAL = {
    "東京": "東京競馬場", "京都": "京都競馬場", "福島": "福島競馬場",
    "中山": "中山競馬場", "阪神": "阪神競馬場", "中京": "中京競馬場",
    "小倉": "小倉競馬場", "札幌": "札幌競馬場", "函館": "函館競馬場",
    "新潟": "新潟競馬場",
}

RACE_HEAD = re.compile(
    r"^###\s+(.+?)(\d+)R\s+(.+?)\s+—\s+(芝|ダート)(\d+)m.*?・(\d{1,2}:\d{2})発走"
)
DAY_HEAD = re.compile(r"^##\s+(\d+)月(\d+)日")
ROUND_PREFIX = re.compile(r"^第\d+回\s+")


def parse_int(cell: str):
    cell = cell.strip()
    return int(cell) if cell.isdigit() else None


def convert(md_path: Path) -> dict:
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", md_path.name)
    if not m:
        raise SystemExit(f"ファイル名から土曜の日付が取れません: {md_path.name}")
    saturday = date(int(m.group(1)), int(m.group(2)), int(m.group(3)))

    lines = md_path.read_text(encoding="utf-8").splitlines()
    races = []
    cur_date = None
    race = None
    table = {}          # 馬名 -> (枠, 馬番, 騎手)
    map_mode = False

    def flush_race():
        nonlocal race, table
        if race is not None:
            merged = []
            seen = set()
            for h in race.pop("_map", []):
                num, bracket, jockey = table.get(h["name"], (None, None, ""))
                merged.append({
                    "number": num, "bracket": bracket, "name": h["name"],
                    "jockey": jockey or h.get("jockey", ""),
                    "style": h["style"], "comment": h["comment"],
                })
                seen.add(h["name"])
            for name, (num, bracket, jockey) in table.items():
                if name not in seen:
                    merged.append({
                        "number": num, "bracket": bracket, "name": name,
                        "jockey": jockey, "style": "", "comment": "",
                    })
            race["horses"] = merged
            races.append(race)
        race = None
        table = {}

    for line in lines:
        dm = DAY_HEAD.match(line)
        if dm and line.startswith("## "):
            flush_race()
            month, day = int(dm.group(1)), int(dm.group(2))
            year = saturday.year + (1 if month < saturday.month else 0)
            cur_date = date(year, month, day).isoformat()
            map_mode = False
            continue
        if line.startswith("## "):
            flush_race()
            cur_date = None
            continue

        rm = RACE_HEAD.match(line)
        if rm and cur_date:
            flush_race()
            venue_short, num, name, surface, dist, start = rm.groups()
            race = {
                "date": cur_date,
                "venue": VENUE_FORMAL.get(venue_short, venue_short + "競馬場"),
                "raceNumber": int(num),
                "raceName": ROUND_PREFIX.sub("", name.strip()),
                "surface": surface,
                "distance": int(dist),
                "startTime": start,
                "courseTrait": "",
                "pace": "",
                "favored": "",
                "notes": [],
                "_map": [],
            }
            map_mode = False
            continue
        if race is None:
            continue

        if line.startswith("**コースで強いタイプ**："):
            race["courseTrait"] = line.split("：", 1)[1].strip()
        elif line.startswith("**脚質マップ**"):
            map_mode = True
        elif line.startswith("**想定される展開**："):
            race["pace"] = line.split("：", 1)[1].strip()
            map_mode = False
        elif line.startswith("**展開面で有利になりそうなタイプと注目馬**："):
            race["favored"] = line.split("：", 1)[1].strip()
            map_mode = False
        elif line.startswith("※"):
            race["notes"].append(line.lstrip("※").strip())
        elif line.startswith("|") and not line.startswith("|-"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not cells or cells[0] in ("枠", "馬名") or set(cells[0]) <= set("-"):
                continue
            if len(cells) >= 4:
                bracket, number, name, jockey = parse_int(cells[0]), parse_int(cells[1]), cells[2], cells[3]
            elif len(cells) == 2:
                bracket, number, name, jockey = None, None, cells[0], cells[1]
            else:
                continue
            if name:
                table[name] = (number, bracket, jockey)
        elif map_mode and line.startswith("- "):
            body = line[2:].strip()
            if " — " not in body:
                continue
            name, rest = body.split(" — ", 1)
            if "。" in rest:
                style, comment = rest.split("。", 1)
                comment = comment.strip().rstrip("。")
            else:
                style, comment = rest, ""
            race["_map"].append({
                "name": name.strip(), "style": style.strip(), "comment": comment,
            })

    flush_race()
    return {"weekend": saturday.isoformat(), "races": races}


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    md_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    data = convert(md_path)
    out_file = out_dir / f"preview-{data['weekend']}.json"
    out_file.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    index_path = out_dir / "preview-index.json"
    weekends = []
    if index_path.exists():
        weekends = json.loads(index_path.read_text(encoding="utf-8")).get("weekends", [])
    if data["weekend"] not in weekends:
        weekends.insert(0, data["weekend"])
    index_path.write_text(
        json.dumps({"weekends": weekends}, ensure_ascii=False, indent=1), encoding="utf-8"
    )

    total_horses = sum(len(r["horses"]) for r in data["races"])
    print(f"{out_file}: {len(data['races'])} races, {total_horses} horses")
    for r in data["races"]:
        print(f"  {r['date']} {r['venue']} {r['raceNumber']}R {r['raceName']} "
              f"{r['surface']}{r['distance']}m {r['startTime']} horses={len(r['horses'])} "
              f"trait={'OK' if r['courseTrait'] else 'MISSING'} pace={'OK' if r['pace'] else 'MISSING'} "
              f"favored={'OK' if r['favored'] else 'MISSING'}")


if __name__ == "__main__":
    main()
