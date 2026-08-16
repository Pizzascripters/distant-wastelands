# Distant Wastelands

Distant Wastelands is a post-apocalyptic 2d survival game that takes place on the surface of Mars. A pathogen wiped out all humans on Earth many years ago, and the colonies on Mars were left to fend for themselves without supply shipments from Earth. In this game, the player builds and maintains scrappy colonies on the Martian surface while defending their colony from AI players that try to ravage their base. The player may also try to steal supplies from enemy bases.

Everything in design.md shall be taken as the exact requirements for the entire game. Any feature in the code that is not defined in the design doc should be removed. Any new requirements should always be added to the design doc.

Don't include references to the name of the game, as it is subject to change.

This game should support LAN multiplayer co-op, and will eventually be compatible with Steam multiplayer.

The game should natively run on both Windows and linux.

When you are finished with a change, create a branch in the format `feature/<name>`, and create a GitHub pull request for it.

Automated tests must be run with `./tools/test.sh` only. That script starts a private Xvfb and never uses the host display. Do not run `godot --headless` for the test runner, and do not launch Godot against `DISPLAY=:0` or the session Wayland/X11 display while testing.