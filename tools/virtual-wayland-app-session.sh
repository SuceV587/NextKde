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

"$app" &
app_pid=$!

cleanup()
{
    if kill -0 "$app_pid" 2>/dev/null; then
        kill -TERM "$app_pid"
        wait "$app_pid" || true
    fi
}
trap cleanup EXIT HUP INT TERM

sleep "${KOS_TEST_CAPTURE_DELAY:-2}"
if ! kill -0 "$app_pid" 2>/dev/null; then
    wait "$app_pid"
    exit $?
fi

timeout 15 spectacle --background --nonotify --output "$KOS_TEST_SCREENSHOT"
test -s "$KOS_TEST_SCREENSHOT"
