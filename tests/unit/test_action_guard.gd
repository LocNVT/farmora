extends GutTest

## Verifies ActionGuard's 300 ms commit-lock semantics (docs/
## ARCHITECTURE.md Section 10.4): first commit allowed, a second within
## the lock window refused, exactly lock_ms later allowed again, keys
## are independent, and a refused attempt does not extend the lock.

var _guard: ActionGuard

func before_each() -> void:
	_guard = ActionGuard.new()

func test_first_commit_is_allowed() -> void:
	assert_true(_guard.try_commit("feed:a1", 1000, 300))

func test_second_commit_within_lock_window_is_refused() -> void:
	_guard.try_commit("feed:a1", 1000, 300)
	assert_false(_guard.try_commit("feed:a1", 1100, 300), "A commit 100ms after the first, inside a 300ms lock, should be refused")

func test_commit_exactly_at_lock_ms_boundary_is_allowed() -> void:
	_guard.try_commit("feed:a1", 1000, 300)
	assert_true(_guard.try_commit("feed:a1", 1300, 300), "A commit exactly lock_ms later should be allowed")

func test_commit_just_before_lock_ms_boundary_is_refused() -> void:
	_guard.try_commit("feed:a1", 1000, 300)
	assert_false(_guard.try_commit("feed:a1", 1299, 300))

func test_different_keys_do_not_block_each_other() -> void:
	_guard.try_commit("feed:a1", 1000, 300)
	assert_true(_guard.try_commit("feed:a2", 1050, 300), "A different key should not be affected by another key's lock")

func test_a_refused_attempt_does_not_extend_the_lock() -> void:
	_guard.try_commit("feed:a1", 1000, 300)
	_guard.try_commit("feed:a1", 1100, 300)  # refused; must not reset the lock's start time
	assert_true(_guard.try_commit("feed:a1", 1300, 300), "The lock should still expire 300ms after the ORIGINAL commit, not the refused attempt")
