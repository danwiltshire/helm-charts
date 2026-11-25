#!/usr/bin/env python3
"""Generate editor schemas for Helm's partially merged environment values."""

import json
from pathlib import Path


def partial_schema(schema):
    if isinstance(schema, bool):
        return schema

    result = schema.copy()
    if "$ref" in result or "dependencies" in result:
        raise ValueError("Override schemas do not support $ref or dependencies in merged maps")

    result.pop("required", None)
    result.pop("minProperties", None)
    for keyword in ("if", "then", "else"):
        result.pop(keyword, None)

    for keyword in ("properties", "patternProperties"):
        if keyword in result:
            result[keyword] = {
                name: partial_schema(value) for name, value in result[keyword].items()
            }
    if isinstance(result.get("additionalProperties"), dict):
        result["additionalProperties"] = partial_schema(result["additionalProperties"])
    for keyword in ("allOf", "anyOf"):
        if keyword in result:
            result[keyword] = [partial_schema(value) for value in result[keyword]]
    if "oneOf" in result:
        alternatives = [partial_schema(value) for value in result.pop("oneOf")]
        result.setdefault("allOf", []).append({"anyOf": alternatives})
    return result


def main():
    root = Path(__file__).resolve().parent.parent
    for source in sorted((root / "apps").glob("*/values.schema.json")):
        schema = json.loads(source.read_text())
        output = source.with_name("values.env.schema.json")
        output.write_text(json.dumps(partial_schema(schema), indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
