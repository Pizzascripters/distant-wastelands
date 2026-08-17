# Distant Wastelands

Distant Wastelands is a post-apocalyptic 2d survival game that takes place on the surface of Mars. A pathogen wiped out all humans on Earth many years ago, and the colonies on Mars were left to fend for themselves without supply shipments from Earth. In this game, the player builds and maintains scrappy colonies on the Martian surface while defending their colony from AI players that try to ravage their base. The player may also try to steal supplies from enemy bases.

Everything in design.md shall be taken as the exact requirements for the entire game. Any feature in the code that is not defined in the design doc should be removed. Any new requirements should always be added to the design doc.

Work items live in GitHub Issues (`label:task`), not in `design.md`. Before starting, list open Todo issues (`is:issue is:open label:task -label:in-progress`), skip any issue that is already `in-progress` or whose blocked-by parents are still open, then claim by adding the `in-progress` label. Close the issue when it merges (`Fixes #<n>` in the PR). Do not encode status in `design.md`.

Don't include references to the name of the game, as it is subject to change.

This game should support LAN multiplayer co-op, and will eventually be compatible with Steam multiplayer.

The game should natively run on both Windows and linux.

Before implementing a new change, always check out `main` and pull the latest changes.

When you are finished with a change, rebase onto the latest `main` and fix any conflicts. Create a branch in the format `feature/<name>`, squash the change into a single commit, push it, and open a GitHub pull request. Do not include a test plan in the pull request description unless it is relevant to the change. Then invoke a reviewer agent to review the pull request. Do not self-review in place of that agent. Address all of the reviewer's feedback, then invoke the reviewer agent again. Repeat this loop until the reviewer approves. After that approval, merge the pull request yourself; do not wait for a human to merge it.

Automated tests must be run with `./tools/test.sh` only. That script starts a private Xvfb and never uses the host display. Do not run `godot --headless` for the test runner, and do not launch Godot against `DISPLAY=:0` or the session Wayland/X11 display while testing.
