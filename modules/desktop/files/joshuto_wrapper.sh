export joshuto_wrap_id="$$"
joshuto_wrap_tmp="$(mktemp -d -t joshuto-wrap-$joshuto_wrap_id-XXXXXX)"
export joshuto_wrap_tmp
export joshuto_wrap_preview_meta="$joshuto_wrap_tmp/preview-meta"
export ueberzug_pid_file="$joshuto_wrap_tmp/pid"
export ueberzug_img_identifier="preview"
export ueberzug_socket=""
export ueberzug_pid=""

# shellcheck disable=SC2317
function start_ueberzugpp {
    ## Adapt Überzug++ options here. For example, remove the '--no-opencv' or set another output method.
    ueberzug layer --no-stdin --pid-file "$ueberzug_pid_file" --no-opencv &>/dev/null
    ueberzug_pid="$(cat "$ueberzug_pid_file")"
    export ueberzug_pid
    export ueberzug_socket=/tmp/ueberzugpp-"$ueberzug_pid".socket
    mkdir -p "$joshuto_wrap_preview_meta"
}

# shellcheck disable=SC2317
function stop_ueberzugpp {
    remove_image
    ueberzug cmd -s "$ueberzug_socket" -a exit
    kill "$ueberzug_pid"
    rm -rf "$joshuto_wrap_tmp"
}

# shellcheck disable=SC2317
function show_image {
    ueberzug cmd -s "$ueberzug_socket" -a add -i "$ueberzug_img_identifier" -x "$2" -y "$3" --max-width "$4" --max-height "$5" -f "$1" &>/dev/null
}

# shellcheck disable=SC2317
function remove_image {
    ueberzug cmd -s "$ueberzug_socket" -a remove -i "$ueberzug_img_identifier" &>/dev/null
}

# shellcheck disable=SC2317
function get_preview_meta_file {
    echo "$joshuto_wrap_preview_meta/$(echo "$1" | md5sum | sed 's/ //g')"
}

export -f get_preview_meta_file
export -f show_image
export -f remove_image

if [ -n "$DISPLAY" ] && command -v ueberzug > /dev/null; then
    trap stop_ueberzugpp EXIT QUIT INT TERM
    start_ueberzugpp
fi

joshuto "$@"
exit $?
