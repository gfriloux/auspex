# auspex

**Zabbix monitoring** widget for the **Quickshell / DankMaterialShell** desktop bar. A
status badge in the bar (problem count + colour of the highest severity) and a *cockpit*
popup listing active problems; auspex **notifies** you when a new problem shows up.

A [Nagstamon](https://nagstamon.de/) rethought as a native DMS plugin, **Zabbix 7.0
oriented**. Data comes from the **JSON-RPC API** (HTTP, **read-only**, polling) — **nothing
to install server-side**, a plain read-only API access is enough.

Spirit and invariants: [`DESIGN.md`](./DESIGN.md). Working method:
[`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md) and [`CLAUDE.md`](./CLAUDE.md).

## Stack

- **View**: QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Data**: `query` (JSON-RPC bodies, pure) → `Zabbix.qml` service (HTTP + `Authorization:
  Bearer` header) → `model` (problems, pure/testable) → `view` (QML).
- **Auth**: Zabbix API token attached to a **read-only** user (the token lives in the
  config/service, never in the data layers nor in the tests).

## Status

**v0.5.0 — web quick-links.** auspex is **installable and usable**: a service polls a real
Zabbix 7.0 instance (HTTP through curl), a **bar badge** shows the state (count + colour of
the worst severity), the **cockpit popout** provides the telemetry header, the **summary bar
segmented** by severity, a **clickable legend** that filters the list, an enriched list and
**polished states** (empty / loading / error / token rejected) plus a polling-cadence footer.
When a **new problem** appears, auspex **warns** you: desktop notification (`notify-send` →
DMS daemon, grouped when several arrive at once) and **badge pulse** — with configurable
**enable switch** and **severity threshold**. Settings (URL / token / interval /
notifications) live in DMS. Hovering a problem reveals **quick-links** that open the **Zabbix
web frontend** (problem page, host page) — **non-mutating** outbound links, built from
**configurable URL templates** (Zabbix 7.0 defaults, base derived from the API URL).

Still to come: the **SSH host** and **graph** quick-links (address resolution / graph
selection are non-trivial) in a dedicated plan. Foundations, invariants and visual direction:
`DESIGN.md`.

## Development

Always enter the Nix dev shell first (it provides quickshell, qmllint/qmlformat/
qmltestrunner, just):

```bash
nix develop
just ci        # full gate: fmt-check + lint + test
```

Other targets: `just test` (golden + Qt Quick Test), `just fmt` (formats the QML),
`just bless` (regenerates the goldens — review the diff), `just changelog` (regenerates
`CHANGELOG.md` through git-cliff). The `Justfile` is the **only** definition of the quality
gates; pre-commit and **GitHub Actions CI** (`.github/workflows/ci.yml`) both call it.

## Code layout

```
src/query/queries.js     ← JSON-RPC body builders (problem.get, trigger.get)
src/model/problems.js    ← parsing, host join, aggregates, delta (pure, golden-tested)
src/model/format.js      ← presentation helpers (severityLabel, relativeTime)
src/view/Zabbix.qml      ← service: HTTP polling (curl/Process) → model
src/view/AuspexWidget.qml← bar badge (PluginComponent) + cockpit mounting
src/view/Cockpit.qml     ← cockpit popout, direction C (telemetry, summary, legend, list)
src/view/Settings.qml    ← settings (URL, token, interval, TLS)
tests/                   ← frozen API fixtures + goldens (expected model)
.claude/plans/           ← per-version plans (plan.md, manual_tests.md, phase0_results.md)
```

## Installation

Through home-manager, as a DankMaterialShell plugin:

```nix
# flake.nix (inputs)
inputs.auspex.url = "github:gfriloux/auspex";

# home-manager config
imports = [inputs.auspex.homeModules.default];
programs.auspex.enable = true;
```

Then, in DMS: **Settings → Plugins → Auspex** to enable the widget, and its settings panel
to fill in the URL and the token.

## Configuration (Zabbix side)

1. Create a **Zabbix user with a read-only role** (no write permission at all).
2. Generate an **API token** for it (Users → API tokens).
3. In the plugin settings: fill in the **URL** of the JSON-RPC endpoint
   (`https://<zabbix>/api_jsonrpc.php`), paste the **token**, set the polling **interval**.
   Tick "Unverified TLS certificate" only if the instance uses a self-signed certificate.

auspex is **read-only**: the token needs no write permission. It is sent by curl in an
`Authorization: Bearer` header (visible only to the current user in the process list —
acceptable for a read-only token; hardening remains possible).

## Release

**SemVer** versioning, changelog derived from **Conventional Commits** (git-cliff). The tag
is set by the **maintainer** (hybrid git policy) and triggers the publication.

1. Bump `plugin.json` (`version`) to the new version.
2. `just changelog` to refresh `CHANGELOG.md`, review the diff, commit.
3. Merge onto `main`, then:

   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z — <title>"
   git push origin vX.Y.Z
   ```

Pushing the tag triggers `.github/workflows/release.yml`: git-cliff generates the release
notes and a **GitHub release** is created. Dependencies (flake inputs, actions) are kept up
to date by **Renovate**.

## License

See [`LICENSE`](./LICENSE).
