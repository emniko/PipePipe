#!/usr/bin/env bash
# Installs the debug APK on the emulator, walks through the main screens and saves
# screenshots (+ UI dumps) to ./screenshots so the UI can be reviewed without a phone.
set -x
PKG=InfinityLoop1309.NewPipeEnhanced.debug
OUT=screenshots
TAP="python3 .github/scripts/ui_tap.py"
mkdir -p "$OUT"

shot() {
  sleep "${2:-3}"
  adb exec-out screencap -p > "$OUT/$1.png"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb shell cat /sdcard/ui.xml > "$OUT/$1.xml"
}

dismiss_dialogs() {
  for _ in 1 2 3 4; do
    $TAP '^(no|ok|cancel|not now|close)$' || break
    sleep 2
  done
}

run_pass() {   # $1 = light | dark
  local mode=$1
  adb shell am force-stop $PKG
  if [ "$mode" = dark ]; then adb shell cmd uimode night yes; else adb shell cmd uimode night no; fi
  adb shell am start -W -n $PKG/org.schabi.newpipe.MainActivity
  sleep 12
  dismiss_dialogs
  shot "${mode}_01_home" 15
  adb shell input swipe 540 1700 540 700 400
  shot "${mode}_02_home_scrolled" 4

  # open a video; YouTube sometimes blocks the CI IP for a stream, then try the next one
  for idx in 0 1 2 3; do
    $TAP 'itemVideoTitleView' --id --index $idx || break
    sleep 15
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    if adb shell cat /sdcard/ui.xml | grep -qi 'IP is blocked\|RETRY'; then
      adb shell input keyevent KEYCODE_BACK; sleep 2
      adb shell input keyevent KEYCODE_BACK; sleep 3
      continue
    fi
    break
  done
  shot "${mode}_03_watch_page" 2
  adb shell input swipe 540 1800 540 900 400
  shot "${mode}_04_watch_page_scrolled" 4
  adb shell input keyevent KEYCODE_BACK
  sleep 3
  shot "${mode}_05_mini_player" 3

  # other bottom tabs
  $TAP '^Subscriptions$' && shot "${mode}_06_subscriptions" 6
  $TAP '^Channels$' && shot "${mode}_07_channels" 6
  $TAP '^Library$' && shot "${mode}_08_library" 6
  $TAP '^Home$' && sleep 3

  # search
  $TAP '^Search$' && sleep 3 && adb shell input text 'lofi' && adb shell input keyevent KEYCODE_ENTER
  shot "${mode}_09_search_results" 12
  adb shell input keyevent KEYCODE_BACK; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 2

  # drawer, opened from the account icon
  $TAP '^Menu$' && shot "${mode}_10_drawer" 3
  adb shell input keyevent KEYCODE_BACK
}

adb install -r -g "$(ls PipePipeClient/app/build/outputs/apk/debug/*x86_64*.apk | head -1)"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb logcat -c

run_pass light
run_pass dark

adb logcat -d > "$OUT/logcat.txt"
grep -n "FATAL EXCEPTION" -A 30 "$OUT/logcat.txt" > "$OUT/crashes.txt" || true
ls -la "$OUT"
