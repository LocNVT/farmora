extends Node

## Root scene per docs/ARCHITECTURE.md Section 4.1/4.3 and Section 17
## ("Boot"). Applies ScreenFit, hosts FarmWorld, and runs Phase 7's real
## boot decision tree against SaveService.load_game() -- replacing the
## Phase 2-6 seam that always started a fresh, empty-farm session (see
## docs/PROGRESS.md "Phase 2 — Animals" for that seam's own history).
##
## Boot tree (the three branches the user approved during Phase 7
## planning -- no Main Menu/Splash/Settings UI exists yet, so there is
## no "tap Play" gate or damaged-save menu to show; this is the
## save/load ENGINE only):
## - OK (from main, tmp, or backup): begin_session(loaded state);
##   quarantine the stale backup/tmp candidates were not the chosen
##   source is NOT done here -- SaveFileIO's own write_atomic() already
##   keeps exactly one backup and overwrites .tmp on the next successful
##   save, so no extra cleanup is needed on a normal OK boot. Enable
##   persistence immediately (no Play-gate in this no-UI scope).
## - NO_SAVE (first launch): begin_session(Game.new_game_state());
##   enable persistence immediately -- the same "no Play-gate" answer.
## - DAMAGED or TOO_NEW: begin_session(Game.new_game_state()) IN MEMORY
##   ONLY. persistence_enabled stays false (SaveService's own default),
##   so nothing overwrites the damaged/too-new file until
##   SaveService.start_new_farm_after_damage() is called -- which has no
##   caller yet, since the "Start new farm" button lives in UI that is
##   out of this phase's scope (the user approved exactly this: "start
##   fresh in memory only, don't touch the file"). push_error() so the
##   condition is visible during development/testing even with no UI to
##   show it to a player.
##
## Main owns application-level composition only (what is shown, when).
## It does not own farm-world content or behavior -- FarmWorld owns that
## itself (ARCHITECTURE.md Section 10.1). Main never reaches into
## FarmWorld's children directly.
##
## Not built here (later phases): SaveService's Main Menu/Settings UI,
## the damaged-save menu, "Start new farm"/"Save now"/"Try now" UI
## wiring, Nav/AudioService autoloads, AppShell modes, tab roots,
## overlays.
##
## Phase 8 (Offline Progression) ENGINE ONLY, per the user's approved
## scope: `Game.offline_progress_applied` is connected before
## `_boot()` calls `begin_session()`, matching ARCHITECTURE.md Section
## 12.4's ordering rule ("before any other prompt") even though there is
## no prompt to order against yet. A qualifying report (`OfflineRules.
## should_show_modal()`) is held in `pending_offline_report` and logged
## for dev visibility; there is no Offline Reward modal, no blocking, no
## Nav queue-holding, and no Android-back-as-Collect -- all of that
## needs Nav/AppShell/the modal component, none of which exist yet.
## `Game.collect_offline_reward()` is fully built and tested (Phase 8
## Task 5) but has no runtime caller here, same precedent as Phase 7's
## `SaveService.start_new_farm_after_damage()`. Offline products stay on
## their animals as READY bubbles, collectible through the existing
## tap-to-collect seam, so nothing is lost by deferring the modal.
##
## `on_app_resumed()` IS real, in-scope wiring (no UI dependency): a new
## `_notification` branch for `NOTIFICATION_APPLICATION_RESUMED`
## (mobile only -- there is no desktop "un-suspend" notification the way
## FOCUS_OUT stands in for PAUSED).

var pending_offline_report: OfflineReport = null

func _ready() -> void:
	ScreenFit.apply(get_window())
	Game.offline_progress_applied.connect(_on_game_offline_progress_applied)
	_boot()

func _boot() -> void:
	var result: LoadResult = SaveService.load_game()
	match result.status:
		DecodeResult.Status.OK:
			Game.begin_session(result.state)
			SaveService.persistence_enabled = true
		DecodeResult.Status.NO_SAVE:
			Game.begin_session(Game.new_game_state())
			SaveService.persistence_enabled = true
		DecodeResult.Status.DAMAGED, DecodeResult.Status.TOO_NEW:
			push_error("Main: save is %s -- starting a fresh in-memory session; the save file is left untouched" % DecodeResult.Status.keys()[result.status])
			Game.begin_session(Game.new_game_state())

## Holds a qualifying report for the (not-yet-built) Offline Reward
## modal to read once it exists. A report that does not qualify
## (GDD Section 9 rule 4: under 5 minutes, or nothing was produced) is
## discarded -- there is nothing to show for it.
func _on_game_offline_progress_applied(report: OfflineReport) -> void:
	if OfflineRules.should_show_modal(report, Game.catalog):
		pending_offline_report = report
		print("Main: offline reward pending (%d products, %d coins value, %.1f min away) -- no modal UI yet, see docs/PROGRESS.md Phase 8" % [
			report.products.values().reduce(func(a: int, b: int) -> int: return a + b, 0),
			report.coin_value,
			report.elapsed_ms / 60000.0,
		])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Phase 0/1 stub. docs/ARCHITECTURE.md Section 15.2 assigns real
		# back handling to Nav.handle_back(), which does not exist until
		# a later phase. Consuming the notification here only prevents
		# the OS from acting on an unhandled back press during this demo.
		pass
	elif what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# ARCHITECTURE.md Section 11.6: "On background... advances to now
		# and calls SaveService.save_now()". FOCUS_OUT is included for
		# desktop testing (alt-tab); PAUSED is the real mobile signal.
		Game.on_app_backgrounded()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# ARCHITECTURE.md Section 12.2's trigger table: a real return
		# from the OS backgrounding/suspending the app. Mobile only.
		Game.on_app_resumed()
