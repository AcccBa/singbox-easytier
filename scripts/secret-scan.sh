#!/usr/bin/env python3
"""secret-scan.sh — 扫本仓（默认含全部历史 blob）里的凭据形态，供 subtree pull 前后自查。

为什么存在：本仓用 git subtree 把两条上游线整段导入，上游历史里的凭据（例如已被上游删除的
Firebase 配置 app/google-services.json）会跟着进来，并被 GitHub secret scanning 报成告警——
即使我们的 HEAD 里根本没有那个文件。事后取证不如事前自查。

用法：
  scripts/secret-scan.sh                 # 扫全部历史 blob（约 1.9 万个，几十秒）
  scripts/secret-scan.sh --worktree      # 只扫工作树（秒级，push 前用）
  scripts/secret-scan.sh --smoke         # 只跑自检（真值/假值双向），不扫仓
退出码：0 = 无命中；1 = 有命中（打印 blob sha 与路径，不打印内容）；2 = 用法/环境错误。
"""
import os, re, subprocess, sys

PATTERNS = {
    "Google API key (AIza…)": rb"AIza[0-9A-Za-z_-]{35}",
    "Google OAuth client id": rb"[0-9]{6,}-[0-9a-z]{28,}\.apps\.googleusercontent\.com",
    "Google OAuth client secret (GOCSPX-)": rb"GOCSPX-[0-9A-Za-z_-]{16,}",
    "Google OAuth access token (ya29.)": rb"ya29\.[0-9A-Za-z_-]{25,}",
    "FCM legacy server key": rb"AAAA[A-Za-z0-9_-]{70,}:[A-Za-z0-9_-]{10,}",
    "PEM private key": rb"BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY",
    "GitHub token": rb"gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}",
    "AWS access key id": rb"AKIA[0-9A-Z]{16}",
    "Slack token": rb"xox[baprse]-[0-9A-Za-z-]{10,}",
    "Stripe secret": rb"sk_(?:live|test)_[0-9a-zA-Z]{20,}",
    "Generic long api-key assignment": rb"(?i)(?:api[_-]?key|secret|token)[\"']?\s*[:=]\s*[\"'][A-Za-z0-9_\-]{32,}[\"']",
}
COMPILED = {k: re.compile(v) for k, v in PATTERNS.items()}

# 自检必须双向：抓到该抓的，且放过不该抓的。只跑"能抓到"会像 mawk 那次一样把"没跑起来"读成"干净"。
TRUE_CASES = {
    "Google API key (AIza…)": b"key=AIzaSyDUMMYKEY1234567890abcdefghij12345",
    "Google OAuth client id": b"id=123456789012-abcdefghijklmnopqrstuvwx1234.apps.googleusercontent.com",
    "PEM private key": b"-----BEGIN RSA PRIVATE KEY-----",
    "GitHub token": b"t=ghp_" + b"x" * 36,
    "AWS access key id": b"AKIA" + b"ABCDEFGHJKLMNP" * 2,
}
FALSE_CASES = [
    b"AIzaSHORT",
    b"123456-abc.apps.googleusercontent.com",
    b"-----BEGIN CERTIFICATE-----",
    b"api_key = \"short\"",
    b"cc0000000108e241a0c601413b4f004046006d8f15dae9999edf39d58df6",  # 单测里的 hex 报文
]


def smoke() -> int:
    for name, probe in TRUE_CASES.items():
        if not COMPILED[name].search(probe):
            print(f"自检失败：{name} 抓不到注入的假值"); return 2
    for probe in FALSE_CASES:
        for name, rx in COMPILED.items():
            if rx.search(probe):
                print(f"自检失败：{name} 对 '{probe[:40]!r}' 误报"); return 2
    print(f"自检通过：{len(TRUE_CASES)} 个真值全抓到，{len(FALSE_CASES)} 个假值零误报")
    return 0


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True, text=True)


def scan_worktree() -> dict:
    hits = {}
    r = git("grep", "-nI", "-e", "BEGIN", "--", ".")  # 仅用于确认 git grep 可用
    if r.returncode not in (0, 1):
        print("git grep 不可用:", r.stderr.strip()); sys.exit(2)
    for name, rx in COMPILED.items():
        r = git("grep", "-nIE", rx.pattern.decode(), "--", ".")
        for line in r.stdout.splitlines():
            hits.setdefault(name, set()).add(("file:" + line.split(":", 1)[0], line.split(":")[1]))
    return hits


def scan_history() -> tuple[dict, int]:
    hdr = re.compile(rb"^([0-9a-f]{40}) blob (\d+)$")
    p = subprocess.Popen(["git", "cat-file", "--batch-all-objects", "--batch"],
                         stdout=subprocess.PIPE)
    cur, hits, objs = b"", {}, 0
    while True:
        line = p.stdout.readline()
        if not line:
            break
        m = hdr.match(line)
        if m:
            cur, objs = m.group(1), objs + 1
            continue
        for name, rx in COMPILED.items():
            if rx.search(line):
                hits.setdefault(name, set()).add(cur.decode())
    p.wait()
    return hits, objs


def paths_for(shas) -> dict:
    r = subprocess.run(["git", "rev-list", "--objects", "--all"], capture_output=True, text=True)
    m = {}
    for line in r.stdout.splitlines():
        parts = line.split(" ", 1)
        if len(parts) == 2 and parts[0] in shas:
            m.setdefault(parts[0], parts[1])
    return m


def main() -> int:
    args = sys.argv[1:]
    if os.path.isdir(".git") is False and os.path.isfile(".git") is False:
        print("必须在仓根运行"); return 2
    if "--smoke" in args:
        return smoke()
    if "--worktree" in args:
        hits = scan_worktree(); total = "工作树"
    else:
        hits, total = scan_history()
    if not hits:
        print(f"无命中（扫描对象：{total}）"); return 0
    shas = {s for v in hits.values() if all(len(x) == 40 for x in v) for s in v}
    pmap = paths_for(shas) if shas else {}
    for name, found in sorted(hits.items()):
        print(f"[{name}] {len(found)} 处")
        for item in sorted(found)[:10]:
            if isinstance(item, tuple):
                print(f"    {item[0]}:{item[1]}")
            else:
                print(f"    {item[:12]}  {pmap.get(item, '（无路径映射，可能为游离对象）')}")
    print("提示：命中≠泄露。上游测试夹具（如 test/config/*.pem 的示例私钥）与已被上游删除的历史文件属误报，")
    print("      但必须逐条判定归属与是否仍在 HEAD 存在，再决定处置。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
