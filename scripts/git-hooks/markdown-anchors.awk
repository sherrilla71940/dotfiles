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

FNR == 1 { fence = ""; prev = ""; scanned[FILENAME] = 1 }  # state must not leak between files
/^[[:space:]]*(```|~~~)/ {
  marker = ($0 ~ /^[[:space:]]*```/) ? "`" : "~"
  if (fence == "") fence = marker                # opening: remember which character it was
  else if (fence == marker) fence = ""           # only the same character closes it
  next
}
fence != "" { next }

# A setext heading is the previous line underlined with = or -, so headings are registered one
# line late; only the slug matters, not the order.
/^[[:space:]]*(=+|-+)[[:space:]]*$/ && prev != "" { record(prev); prev = ""; next }
/^#{1,6}[[:space:]]/ {
  h = $0
  sub(/^#+[[:space:]]+/, "", h)
  record(h)
  prev = ""
  next
}
{ prev = $0 }

function record(h,   slug) {
  gsub(/\]\([^)]*\)/, "]", h)                   # a link in a heading contributes its text only;
  gsub(/[][]/, "", h)                           # awk gsub has no backreference, so do it in two
  gsub(/`|\*/, "", h)                           # code spans and emphasis do not reach the slug
  slug = tolower(h)
  gsub(/[^a-z0-9 _-]/, "", slug)                # underscores DO survive into a GitHub anchor
  gsub(/ /, "-", slug)
  # GitHub disambiguates a repeated heading by appending -1, -2, ... in document order.
  if ((FILENAME SUBSEP slug) in heading) {
    seen[FILENAME SUBSEP slug]++
    heading[FILENAME SUBSEP slug "-" seen[FILENAME SUBSEP slug]] = 1
  } else {
    heading[FILENAME SUBSEP slug] = 1
  }
}

{
  # Two forms: a relative link into another file, and a bare fragment inside this one.
  line = $0
  gsub(/`[^`]*`/, "", line)                     # a link inside a code span is being shown, not made
  gsub(/<!--.*-->/, "", line)                   # nor is one inside a comment
  while (match(line, /\]\([A-Za-z0-9._\/-]*#[A-Za-z0-9._-]+\)/)) {
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
    # A markdown file with no lines never reaches FNR == 1, so confirm on disk before blaming
    # the path rather than the fragment.
    if (!(target in scanned) && system("test -f \"" target "\"") != 0) why = "no such file"
    else if (!(target SUBSEP part[2] in heading)) why = "no such heading"
    else continue
    printf "    %s:%d -> %s (%s)\n", src[i], lno[i], raw[i], why
    bad++
  }
  if (bad) exit 1
  print total
}
