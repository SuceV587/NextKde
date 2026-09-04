#!/bin/sh

set -eu

app=${KOS_TEST_APP:?Set KOS_TEST_APP to the absolute path of an application}

if [ ! -x "$app" ]; then
    echo "Application is not executable: $app" >&2
    exit 2
fi

if [ -z "${KOS_TEST_SCREENSHOT:-}" ]; then
    exec "$app" --smoke-test
fi

if [ -n "${KOS_TEST_APP_ARGUMENT:-}" ]; then
    "$app" "$KOS_TEST_APP_ARGUMENT" &
else
    "$app" &
fi
app_pid=$!

cleanup()
{
    if kill -0 "$app_pid" 2>/dev/null; then
        kill -TERM "$app_pid"
        wait "$app_pid" || true
    fi
}
trap cleanup EXIT HUP INT TERM

if [ -n "${KOS_TEST_MPRIS_OPEN_URI:-}" ]; then
    attempt=0
    until gdbus introspect --session \
        --dest org.mpris.MediaPlayer2.kosmusic \
        --object-path /org/mpris/MediaPlayer2 >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge 30 ]; then
            echo "KOS Music did not publish MPRIS in time" >&2
            exit 3
        fi
        sleep 0.1
    done
    gdbus call --session \
        --dest org.mpris.MediaPlayer2.kosmusic \
        --object-path /org/mpris/MediaPlayer2 \
        --method org.mpris.MediaPlayer2.Player.OpenUri \
        "$KOS_TEST_MPRIS_OPEN_URI" >/dev/null
fi

sleep "${KOS_TEST_CAPTURE_DELAY:-2}"
if ! kill -0 "$app_pid" 2>/dev/null; then
    wait "$app_pid"
    exit $?
fi

timeout 15 spectacle --background --nonotify --output "$KOS_TEST_SCREENSHOT"
test -s "$KOS_TEST_SCREENSHOT"
