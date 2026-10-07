# Contributing

Thank you for helping to improve the TradeNova OpenTelemetry labs. Fixes to lab steps, configuration, scripts and documentation are all welcome.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a problem

Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) first. If the problem isn't there, open an issue with:

- the day and the lab or scenario
- your operating system, and your Docker or Multipass version
- the command you ran and what happened
- the relevant output: `docker compose ps` and `docker compose logs <service>` for Days 1 and 2, `scripts/status.sh` for Day 3

Report security problems privately, as described in [SECURITY.md](SECURITY.md).

## Proposing a change

1. Fork the repository and create a branch from the default branch.
2. Make the change in the day folder it belongs to. Keep each pull request to one topic.
3. Test it (see below).
4. Open a pull request that says what the change fixes and how you tested it.

## Rules for lab material

These labs are followed step by step by people who are new to the tools, so a small inconsistency can cost a class a lot of time.

**Keep the finished states in step.** A change to a file that a lab edits must also be made in every snapshot that contains that file:

- Day 1: `solutions/after-lab-b` to `after-lab-e`
- Day 2: `scenarios/00-start` and each `scenarios/0N-*/after` (the states are cumulative)
- Day 3: `labs/00-start` and each `labs/lab*/after`

**Keep the starting state broken on purpose.** Many files start in a "problem" state that a lab then fixes, such as the propagation bugs in Day 1's `settlement-service` and the Day 2 agent configuration. Don't fix these in the starting state.

**Pin versions.** Images, charts and agents use exact versions. When you change one, update the version table or list in that day's README.

**Keep shell scripts portable.**

- Shell scripts use LF line endings; the `.gitattributes` in each day folder enforces this.
- Days 1 and 2 ship each script for both bash and PowerShell. Change both.
- Day 3 scripts are bash only and must work in Git Bash on Windows.

**Don't commit generated files or secrets.** Build output such as `target/` and `node_modules/` is ignored. The lab settings files (`.env`, `lab.env`, `config/*.env`) are tracked on purpose: keep the course defaults in them, and never commit a real registry password or token.

**Update the documentation.** If a command, port, file name or symptom changes, update that day's README and, where it applies, [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and the root [README.md](README.md).

## Testing a change

Run the lab you changed from a clean state, on the path a participant would take:

| Day | Clean start | Then check |
| --- | --- | --- |
| 1 | `docker compose --profile load down -v`, then `docker compose up -d --build` | The lab works by hand, and `scripts/catch-up.sh <lab>` reaches the same state |
| 2 | `scripts/reset-to-start.sh`, then `docker compose up -d --build` | The scenario works by hand, and `scripts/apply-scenario.sh N` reaches the same state |
| 3 | `scripts/reset-labs.sh` | `scripts/apply-lab.sh N` and `scripts/status.sh`; test with `LIGHT_MODE=1` too if the change touches the participant kit |

If you could not test on one of the supported systems (Windows, macOS, Linux), say so in the pull request.

## Changelog

Add a line to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md) for any change a participant or instructor would notice.

## License

Contributions are licensed under the [MIT License](LICENSE), the same as the rest of the repository.
