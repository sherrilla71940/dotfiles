statusline_output_has_content() {
  local output="$1"
  [[ -n "${output//[[:space:]]/}" ]]
}
