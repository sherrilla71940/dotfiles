# Verify that every markdown link carrying a #fragment resolves to a real heading, whether it
# points into another file relatively or at a heading in the same file.
#
# Anchor rot is silent: the link still renders, and only fails when a reader clicks it. The
# guides and the decision records cross-reference each other by anchor, so renaming one
# heading can break several files at once.
#
# Prints the number of links checked and exits 0 when they all resolve; prints the offenders
# and exits 1 when they do not.
#
# Fenced blocks are skipped on both sides: their "# comment" lines are not headings, and the
# links inside them are usually illustrative templates naming files that do not exist.

function normalise(dir, path,   parts, n, out, i, top, result) {
  n = split(dir "/" path, parts, "/")
  top = 0
  for (i = 1; i <= n; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == "..") { if (top > 0) top--; continue }
    out[++top] = parts[i]
  }
  result = ""
  for (i = 1; i <= top; i++) result = result (i > 1 ? "/" : "") out[i]
  return result
}

FNR == 1 { fence = 0; scanned[FILENAME] = 1 }   # fence state must not leak between files
/^[[:space:]]*(```|~~~)/ { fence = !fence; next }
fence { next }

/^#{1,6}[[:space:]]/ {
  h = $0
  sub(/^#+[[:space:]]+/, "", h)
  gsub(/`|\*|_/, "", h)                         # code spans and emphasis do not reach the slug
  h = tolower(h)
  gsub(/[^a-z0-9 -]/, "", h)
  gsub(/ /, "-", h)
  heading[FILENAME SUBSEP h] = 1
  next
}

{
  # Two forms: a relative link into another file, and a bare fragment inside this one.
  line = $0
  while (match(line, /\]\((\.[^)]*)?#[A-Za-z0-9_-]+\)/)) {
    src[++total] = FILENAME
    raw[total] = substr(line, RSTART + 2, RLENGTH - 3)
    lno[total] = FNR
    line = substr(line, RSTART + RLENGTH)
  }
}

END {
  for (i = 1; i <= total; i++) {
    split(raw[i], part, "#")
    if (part[1] == "") {
      target = src[i]                             # bare #fragment: same file
    } else {
      dir = src[i]
      if (!sub(/\/[^\/]*$/, "", dir)) dir = "."
      target = normalise(dir, part[1])
    }
    if (!(target in scanned)) why = "no such file"
    else if (!(target SUBSEP part[2] in heading)) why = "no such heading"
    else continue
    printf "    %s:%d -> %s (%s)\n", src[i], lno[i], raw[i], why
    bad++
  }
  if (bad) exit 1
  print total
}
