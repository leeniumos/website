#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBSITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LEENIUM_DIR="$(cd "$WEBSITE_DIR/../leenium" && pwd)"

OUT_HTML="$WEBSITE_DIR/manual/keybindings/generated-table.html"
OUT_META="$WEBSITE_DIR/manual/keybindings/generated-meta.txt"

parse_file() {
  local label="$1"
  local file="$2"

  awk -v label="$label" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^[ \t]*bind[a-z]*[ \t]*=/ {
    line = $0
    sub(/^[ \t]*/, "", line)
    split(line, lr, "=")
    bind_type = trim(lr[1])

    rhs = substr(line, index(line, "=") + 1)
    n = split(rhs, f, ",")
    for (i = 1; i <= n; i++) f[i] = trim(f[i])

    mods = f[1]
    key = f[2]
    third = f[3]
    fourth = f[4]

    has_desc = 1
    if (third == "" || third ~ /^\$/) has_desc = 0
    if (third == "exec" || third == "sendshortcut" || third == "killactive" || third == "layoutmsg" || third == "pseudo" || third == "togglefloating" || third == "fullscreen" || third == "fullscreenstate" || third == "movefocus" || third == "workspace" || third == "movetoworkspace" || third == "movetoworkspacesilent" || third == "togglespecialworkspace" || third == "movecurrentworkspacetomonitor" || third == "swapwindow" || third == "cyclenext" || third == "bringactivetotop" || third == "resizeactive" || third == "movewindow" || third == "resizewindow" || third == "togglegroup" || third == "moveoutofgroup" || third == "moveintogroup" || third == "changegroupactive") has_desc = 0

    action = ""
    if (has_desc == 1) {
      action = third
    } else {
      action = third
      for (i = 4; i <= n; i++) {
        if (f[i] == "") continue
        action = action " " f[i]
      }
      gsub(/[ \t]+/, " ", action)
      action = trim(action)
      sub(/^exec[ ]+/, "", action)
    }

    mods = trim(mods)
    key = trim(key)

    if (mods == "") combo = key
    else combo = mods " + " key

    print label "\t" bind_type "\t" combo "\t" action
  }
  ' "$file"
}

generate_rows() {
  {
    parse_file "Applications" "$LEENIUM_DIR/config/hypr/bindings.conf"
    parse_file "Clipboard" "$LEENIUM_DIR/default/hypr/bindings/clipboard.conf"
    parse_file "Media" "$LEENIUM_DIR/default/hypr/bindings/media.conf"
    parse_file "Tiling" "$LEENIUM_DIR/default/hypr/bindings/tiling-v2.conf"
    parse_file "Utilities" "$LEENIUM_DIR/default/hypr/bindings/utilities.conf"
    parse_file "Legacy" "$LEENIUM_DIR/default/hypr/plain-bindings.conf"
    parse_file "Legacy" "$LEENIUM_DIR/default/hypr/bindings.conf"
  } |
    awk -F'\t' '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      {
        section = $1
        type = $2
        combo = trim($3)
        action = trim($4)

        gsub(/ +/, " ", combo)
        gsub(/SUPER/, "Super", combo)
        gsub(/SHIFT/, "Shift", combo)
        gsub(/CTRL/, "Ctrl", combo)
        gsub(/ALT/, "Alt", combo)

        key = combo
        gsub(/code:10/, "1", key)
        gsub(/code:11/, "2", key)
        gsub(/code:12/, "3", key)
        gsub(/code:13/, "4", key)
        gsub(/code:14/, "5", key)
        gsub(/code:15/, "6", key)
        gsub(/code:16/, "7", key)
        gsub(/code:17/, "8", key)
        gsub(/code:18/, "9", key)
        gsub(/code:19/, "0", key)
        gsub(/code:20/, "-", key)
        gsub(/code:21/, "=", key)
        gsub(/mouse:272/, "MOUSE_LEFT", key)
        gsub(/mouse:273/, "MOUSE_RIGHT", key)
        gsub(/mouse:274/, "MOUSE_MIDDLE", key)
        gsub(/MOUSE_DOWN|mouse_down/, "SCROLL_DOWN", key)
        gsub(/MOUSE_UP|mouse_up/, "SCROLL_UP", key)
        gsub(/RETURN/, "ENTER", key)
        gsub(/ESCAPE/, "ESC", key)
        gsub(/Kp_Add/, "NUMPAD_PLUS", key)
        gsub(/Kp_Subtract/, "NUMPAD_MINUS", key)

        if (key ~ / \+ /) {
          split(key, kp, / \+ /)
          mods = kp[1]
          final = kp[2]
          gsub(/ /, " + ", mods)
          key = mods " + " final
        }

        if (action == "") next

        row = section "\t" type "\t" key "\t" action
        if (!seen[row]++) print row
      }
    ' |
    awk -F'\t' '
      BEGIN {
        print "<div class=\"kbd-shell\">"
      }
      {
        sec=$1; typ=$2; key=$3; action=$4;
        if (sec != current) {
          if (current != "") {
            print "      </tbody>"
            print "    </table>"
            print "  </section>"
          }
          print "  <section class=\"section\">"
          print "    <h2>" sec "</h2>"
          print "    <table class=\"kbd-table\">"
          print "      <thead><tr><th>Shortcut</th><th>Action</th><th>Type</th></tr></thead>"
          print "      <tbody>"
          current=sec
        }

        gsub(/&/, "\\&amp;", key)
        gsub(/</, "\\&lt;", key)
        gsub(/>/, "\\&gt;", key)
        gsub(/"/, "\\&quot;", key)

        gsub(/&/, "\\&amp;", action)
        gsub(/</, "\\&lt;", action)
        gsub(/>/, "\\&gt;", action)
        gsub(/"/, "\\&quot;", action)

        print "        <tr><td><code>" key "</code></td><td>" action "</td><td><code>" typ "</code></td></tr>"
      }
      END {
        if (current != "") {
          print "      </tbody>"
          print "    </table>"
          print "  </section>"
        }
        print "</div>"
      }
    '
}

generated_at="$(date -u +"%Y-%m-%d %H:%M:%SZ")"
generate_rows > "$OUT_HTML"
printf 'Generated from Leenium bindings on %s\n' "$generated_at" > "$OUT_META"

echo "Wrote $OUT_HTML"
echo "Wrote $OUT_META"
