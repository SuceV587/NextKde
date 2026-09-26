# Interaction and animation regressions

The September 2026 review identified the following twelve defects. The fixes
share the existing controls, popup motion and service APIs rather than adding
parallel implementations.

| # | Trigger | Result after this change |
| --- | --- | --- |
| 1 | Clipboard focus does not return, changes, or the target closes | Automatic paste is canceled; copied content remains available. KWin also checks the expected window UUID and actual keyboard surface before injecting. |
| 2 | Delete in the clipboard search field | Text editing wins, including Ctrl+Delete. Row deletion uses its button or Ctrl+Shift+Delete. |
| 3 | Pointer returns during Dock hiding | The animation reverses from its current progress and finishes visible. |
| 4 | Files refresh after manually moving an icon | Existing slots survive; new files occupy free slots. Placements persist per output, and rename migrates the stored path. Explicit Arrange/Reset still reorders icons. |
| 5 | A settings switch receives an asynchronous reply | The checked binding remains intact and reflects confirmed state, including subsequent external updates. |
| 6 | A glass switch animates | Thumb and shadow follow the same animated position; no second position easing trails behind it. |
| 7 | A floating panel reopens during its exit | The latest open request reverses the close; toggle uses requested state. |
| 8 | Slider dragging is canceled by hiding or disabling | The host leaves preview mode and resumes service synchronization without committing the canceled value. |
| 9 | A pressed glass button/switch is released outside | Pressed visuals reset without triggering an action. |
| 10 | Saved Dock/Bar mode has not loaded at startup | Both controllers wait for initialized configuration or the existing bounded fallback. |
| 11 | Dock dimensions, edge or screen geometry change | Collision state is recomputed before visibility is evaluated. |
| 12 | Overview or QuickSearch closes | The surface remains mapped through its exit animation, with keyboard and pointer input released immediately. Reopening reverses that animation. |

This branch also includes recovery after removing every widget and the separate
widget appearance setting under Settings → Theme. Widget artwork and content
ink no longer read application icon colour mode. Existing appearance files
migrate once to schema 29, preserving the old widget appearance. Material keeps
its tonal card policy.

## Verification

- `tests/interaction-controls/tst_controls.qml`: real pointer events, async
  switch state, thumb/shadow alignment, slider hide/disable cancellation.
- `tests/interaction-runtime/run.py`: real Quickshell controllers and windows,
  synthetic window records, clipboard requests captured by a fake platform,
  and desktop layout persistence across separate Shell processes.
- `tests/widget-experience/run.py`: empty desktop recovery, gesture routing,
  18 form/widget/icon combinations, migration and persistence.
- Settings QtTest fixtures: checkbox acknowledgement, window grouping switch
  acknowledgement, widget appearance acknowledgement and failure handling.
- Platform startup on a private D-Bus session: rejects missing/invalid paste
  targets and a missing input effect without injecting input.
- Compile `kos-settings`, `kos-platform`, and `kos_context_menu_input`.

The fixtures never paste into real applications. The KWin guard is compiled;
live key injection and compositor frame timing are not measured by these tests.
The guarded `input.paste` contract requires the matching KWin input plugin.
An older loaded plugin fails safely, leaving the copied content available.

The tests are registered with CTest. Run logic/platform checks with
`./tools/run-tests.sh --layer logic --layer platform`, and the relevant UI tests
on a Wayland desktop:

```sh
ctest --test-dir .build/tests --output-on-failure \
  -R 'kos-ui.interaction|kos-ui.widget-experience|kos-settings\.|kos-deskcenter.density-runtime'
```

## Existing PR compatibility

PR #111 contains the Wi-Fi discovery and confirmation-label fixes. This branch
starts from `main` and does not include that PR's commit. The shared files are
`ControlCenterPanel.qml` and `PlatformServer.cpp`; these changes touch slider
cancellation and guarded paste, respectively. The Wi-Fi and confirmation-label
changes are kept separate.
