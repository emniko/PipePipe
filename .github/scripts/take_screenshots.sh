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
  dismiss_dialogs
  adb exec-out screencap -p > "$OUT/$1.png"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb shell cat /sdcard/ui.xml > "$OUT/$1.xml"
}

dismiss_dialogs() {
  # app dialogs (What's new, announcement, donation) and system "isn't responding" dialogs
  for _ in 1 2 3 4 5 6; do
    $TAP '^(no|ok|cancel|not now|wait)$' || break
    sleep 1
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
  # a regular (not live) video from the results
  $TAP 'itemVideoTitleView' --id --index 1 && shot "${mode}_09b_watch_page_video" 15
  adb shell input swipe 540 1800 540 900 400
  shot "${mode}_09c_watch_page_video_scrolled" 4
  adb shell input keyevent KEYCODE_BACK; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 2

  # drawer, opened from the account icon
  $TAP '^Menu$' && shot "${mode}_10_drawer" 3
  adb shell input keyevent KEYCODE_BACK
}

# let the launcher settle so it doesn't show "isn't responding" over the app
adb shell input keyevent KEYCODE_HOME
sleep 30
dismiss_dialogs

adb install -r -g "$(ls PipePipeClient/app/build/outputs/apk/debug/*x86_64*.apk | head -1)"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb logcat -c

shorts_and_rotation() {
  adb shell am force-stop $PKG
  adb shell cmd uimode night no
  adb shell am start -W -n $PKG/org.schabi.newpipe.MainActivity
  sleep 12
  dismiss_dialogs

  # Shorts: tiles in search results, then the swipe player
  for _ in 1 2 3; do
    $TAP '^Search$' && break
    sleep 3; dismiss_dialogs
  done
  sleep 3
  adb shell input text 'funny%scat%sshorts'
  adb shell input keyevent KEYCODE_ENTER
  shot "shorts_01_search_tiles" 12
  adb shell input swipe 540 1700 540 900 400
  shot "shorts_02_search_tiles_scrolled" 4
  if $TAP 'itemScrim' --id; then
    shot "shorts_03_player" 15
    adb shell input swipe 540 1600 540 400 250
    shot "shorts_04_player_next" 15
    adb shell input tap 540 1000
    shot "shorts_05_player_paused" 2
    adb shell input keyevent KEYCODE_BACK; sleep 3
  fi
  adb shell input keyevent KEYCODE_BACK; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 2

  # Fullscreen and rotation: YouTube refuses to play on CI machines, so switch the app to
  # media.ccc.de (through the drawer) and use one of its videos.
  $TAP '^Menu$'; sleep 2
  $TAP 'drawer_header_action_button' --id; sleep 2
  $TAP '^media\.ccc\.de$'; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 8
  dismiss_dialogs
  shot "rot_00_ccc_home" 3
  $TAP 'itemVideoTitleView' --id
  shot "rot_01_portrait" 20

  # fullscreen button with auto-rotate off, then on
  for mode in off on; do
    if [ $mode = off ]; then adb shell settings put system accelerometer_rotation 0;
    else adb shell settings put system accelerometer_rotation 1; fi
    adb shell input tap 540 400; sleep 1
    $TAP 'screenRotationButton' --id
    shot "rot_02_fullscreen_button_autorotate_${mode}" 6
    adb shell input tap 1200 540; sleep 1
    $TAP 'screenRotationButton' --id
    shot "rot_03_fullscreen_exit_autorotate_${mode}" 6
  done

  # turning the device with auto-rotate off
  adb shell settings put system accelerometer_rotation 0
  adb emu rotate; shot "rot_04_turned_autorotate_off" 8
  adb emu rotate; adb emu rotate; adb emu rotate; shot "rot_05_turned_back" 8
  adb shell settings put system accelerometer_rotation 1

  # back to YouTube for the dark pass
  adb shell input keyevent KEYCODE_BACK; sleep 2
  $TAP '^Menu$'; sleep 2
  $TAP 'drawer_header_action_button' --id; sleep 2
  $TAP '^YouTube$'; sleep 2
  adb shell input keyevent KEYCODE_BACK; sleep 2
}


run_pass light
shorts_and_rotation
run_pass dark

adb logcat -d > "$OUT/logcat.txt"
grep -n "FATAL EXCEPTION" -A 30 "$OUT/logcat.txt" > "$OUT/crashes.txt" || true
ls -la "$OUT"
