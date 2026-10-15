# swPackage

<p align="center">
  <img src="assets/swpackage-logo.png" alt="swPackage" width="220" />
</p>

Family umbrella for the **sw** Luau tools used together in Roblox games.

| Tool | Role | On `main` | Branch |
|---|---|---|---|
| **swTASK** | Structured concurrency (jobs, scopes, flows, adapters) | [`swTASK/`](./swTASK) | [`swTASK`](https://github.com/0bArc/swPackage/tree/swTASK) |
| **swNET** | Buffer-based typed networking | [`swNET/`](./swNET) | [`swNET`](https://github.com/0bArc/swPackage/tree/swNET) |

`main` holds both packages as folders. Named branches mirror each package root for single-product clones. Branches share history with `main` (no orphan compare / merge noise).

## Clone everything

```bash
git clone https://github.com/0bArc/swPackage.git
cd swPackage
# use ./swTASK and ./swNET
```

## Clone one product (branch tip is that package root)

```bash
git clone -b swTASK --single-branch https://github.com/0bArc/swPackage.git swTASK
git clone -b swNET --single-branch https://github.com/0bArc/swPackage.git swNET
```

## How they fit

- **swNET** defines packets, batches remotes, encodes buffers.
- **swTASK** runs game work as Jobs; attach packet listeners with `SwTask.swnet:on` so handlers stay on the job pool.

Use them together or alone. Each package has docs under its own `docs/` folder.

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

Each package ships under MIT (see `swTASK/LICENSE` and `swNET/LICENSE`).
