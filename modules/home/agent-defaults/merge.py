"""Merge home-manager agent defaults into a tool-owned config file.

Usage: merge.py FORMAT DEFAULTS TARGET STATE

TARGET stays a regular file the tool can rewrite. STATE remembers the defaults
applied last time, which makes this a three-way merge: a value in TARGET that
still equals the previous default follows DEFAULTS, a value the tool changed is
kept, and a key missing from TARGET falls back to DEFAULTS the way a
lower-precedence settings layer would.
"""

import json
import os
import sys
import tempfile

import yaml

ABSENT = object()


def same(a, b):
    if a is ABSENT or b is ABSENT:
        return a is b
    return json.dumps(a, sort_keys=True, default=str) == json.dumps(
        b, sort_keys=True, default=str
    )


def merge(base, cur, new):
    """Merge one value. Returning ABSENT drops the key."""
    if cur is ABSENT or same(cur, base):
        return new
    if not isinstance(cur, dict):
        return cur
    if new is ABSENT:
        if not isinstance(base, dict):
            return cur
        new = {}
        dropped = True
    elif isinstance(new, dict):
        dropped = False
    else:
        return cur

    base = base if isinstance(base, dict) else {}
    out = {}
    for key in [*cur, *(k for k in new if k not in cur)]:
        value = merge(
            base.get(key, ABSENT), cur.get(key, ABSENT), new.get(key, ABSENT)
        )
        if value is not ABSENT:
            out[key] = value
    return ABSENT if dropped and not out else out


def load(path, fmt):
    with open(path) as f:
        text = f.read()
    if not text.strip():
        return ABSENT
    return json.loads(text) if fmt == "json" else yaml.safe_load(text)


def dump(value, fmt):
    if fmt == "json":
        return json.dumps(value, indent=2, ensure_ascii=False) + "\n"
    return yaml.safe_dump(
        value, sort_keys=False, allow_unicode=True, default_flow_style=False
    )


def write_atomic(path, text, mode):
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".agent-defaults-")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def managed_link(path):
    """Symlinks from the old home-manager or sops-nix setup hold no tool edits."""
    real = os.path.realpath(path)
    return (
        not os.path.exists(real)
        or real.startswith("/nix/store/")
        or "/secrets.d/" in real
    )


def warn(message):
    print(f"agent-defaults: {message}", file=sys.stderr)


def main():
    fmt, defaults_path, target, state_path = sys.argv[1:]

    try:
        new = load(defaults_path, fmt)
    except FileNotFoundError:
        warn(f"{defaults_path} is missing, leaving {target} unchanged")
        return
    if new is ABSENT:
        new = {}

    if os.path.islink(target) and not managed_link(target):
        target = os.path.realpath(target)

    cur = ABSENT
    mode = 0o600
    if os.path.isfile(target) and not os.path.islink(target):
        mode = os.stat(target).st_mode & 0o777
        try:
            cur = load(target, fmt)
        except (ValueError, yaml.YAMLError) as e:
            warn(f"cannot parse {target} ({e}), leaving it unchanged")
            return

    try:
        base = load(state_path, "json")
    except (OSError, ValueError):
        base = ABSENT

    result = merge(base, cur, new)
    if result is ABSENT:
        result = {}

    if os.path.islink(target) or not same(result, cur):
        write_atomic(target, dump(result, fmt), mode)
        print(f"agent-defaults: updated {target}")

    write_atomic(state_path, json.dumps(new, indent=2) + "\n", 0o600)


if __name__ == "__main__":
    main()
