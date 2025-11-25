---
description: Convert Python script to uv-runnable with PEP 723 inline metadata
---

Convert the specified Python script to include PEP 723 inline metadata so it can be run with `uv run`.

1. Read the script
2. Detect dependencies from imports
3. Add PEP 723 metadata block:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "package1",
# ]
# ///
```

4. Preserve existing code and structure
