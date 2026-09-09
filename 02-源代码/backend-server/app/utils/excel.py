"""Excel 导入导出工具（openpyxl / pandas 可选）。"""
from __future__ import annotations
import io, csv, logging
from typing import Any

logger = logging.getLogger(__name__)

def parse_csv(content: bytes, encoding: str = "utf-8") -> list[dict[str, str]]:
    text = content.decode(encoding)
    reader = csv.DictReader(io.StringIO(text))
    return [row for row in reader]

def export_csv(rows: list[dict[str, Any]], columns: list[str] | None = None) -> bytes:
    if not rows:
        return b""
    cols = columns or list(rows[0].keys())
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=cols)
    writer.writeheader()
    for row in rows:
        writer.writerow({k: row.get(k, "") for k in cols})
    return output.getvalue().encode("utf-8")

def validate_import_report(items: list[dict], required_fields: list[str]) -> dict:
    success_list: list[str] = []
    failed_list: list[dict] = []
    for item in items:
        missing = [f for f in required_fields if not item.get(f)]
        if missing:
            failed_list.append({"item": str(item), "reason": f"缺少必填字段：{', '.join(missing)}"})
        else:
            success_list.append(str(item))
    return {"success": len(success_list), "failed": len(failed_list), "success_list": success_list, "failed_list": failed_list}
