# swPackage

<p align="center">
  <img src="assets/swpackage-logo.png" alt="swPackage" width="220" />
</p>

Family umbrella for the **sw** Luau tools used together in Roblox games.

| Tool | Role | Branch |
|---|---|---|
| **swTASK** | Structured concurrency (jobs, scopes, flows, adapters) | [`swTASK`](https://github.com/0bArc/swPackage/tree/swTASK) |
| **swNET** | Buffer-based typed networking | [`swNET`](https://github.com/0bArc/swPackage/tree/swNET) |

This `main` branch is the landing page (readme + brand). Product source lives on the named branches above.

## Clone a product branch

```bash
git clone -b swTASK https://github.com/0bArc/swPackage.git swTASK
git clone -b swNET https://github.com/0bArc/swPackage.git swNET
```

Or fetch both into one clone:

```bash
git clone https://github.com/0bArc/swPackage.git
cd swPackage
git checkout swTASK
git checkout swNET
```

## How they fit

- **swNET** defines packets, batches remotes, encodes buffers.
- **swTASK** runs game work as Jobs; attach packet listeners with `SwTask.swnet:on` so handlers stay on the job pool.

Use them together or alone. Each branch has its own docs under `docs/`.

## Brand

White mark on transparent PNG:

| File | Size |
|---|---|
| `assets/swpackage-logo.png` | 1024 |
| `assets/swpackage-logo-512.png` | 512 |
| `assets/swpackage-logo-256.png` | 256 |
| `assets/swpackage-logo-128.png` | 128 |
| `assets/swpackage-logo-64.png` | 64 |

## License

Product branches ship under MIT (see `LICENSE` on each branch).
