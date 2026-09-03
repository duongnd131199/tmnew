# Font provenance

Retrieved from official Google Fonts repositories on 2026-08-26.

| Asset | Upstream | Version | License | SHA-256 |
| --- | --- | --- | --- | --- |
| `Roboto-Variable.ttf` | `https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto%5Bwdth%2Cwght%5D.ttf` | 3.015 | `OFL-Roboto.txt` | `d7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134` |
| `RobotoCondensed-Variable.ttf` | `https://raw.githubusercontent.com/google/fonts/main/ofl/robotocondensed/RobotoCondensed%5Bwght%5D.ttf` | 3.008 | `LICENSE-RobotoCondensed-Apache-2.0.txt` | `dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0` |

The Roboto Condensed binary retains its upstream Apache 2.0 name-table
metadata, so its matching license is sourced from
`https://github.com/googlefonts/roboto-3-classic/blob/v3.008/LICENSE.txt`.

## Isolated MetaTrader reference inputs

The `mt5-reference/` directory contains four static Apache-2.0 faces extracted
from the official `net.metaquotes.metatrader5` version `500.6140` package after
the live APK matched the pinned SHA-256
`c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b`.
`font-lock.json` records the exact package, font hashes, SFNT metadata, legal
weights, role groups, and license evidence. These files use isolated Flutter
family aliases and do not change existing production typography behavior.

Schema 3 requires the four static package faces plus the reviewed
`RobotoCondensed-Variable.ttf` input above. The variable file remains at its
single existing asset path, is registered through the isolated
`Mt5ReferenceRobotoCondensedVariable` alias, and is locked to its exact `wght`
axis and reviewed trade/history role groups. This avoids bundling a duplicate
binary.
Schema 3 accepts those five literal baseline records or those five plus one
`Mt5ReferenceNumeric` entry with the complete numeric-only role set, a
direct-font source SHA, and independently hashed license evidence.

The exact specimen `4637.05 → 4640.81` is immutable. U+2192 is the sole typed
candidate-face cmap exception because the four 2013 faces do not contain it;
Task 2 must consume key `numeric-price-arrow` and render that delimiter as a
deterministic vector shape. Silent font fallback is forbidden.

The package's Avenir face is intentionally absent because redistribution rights
have not been established. It may not be copied into this directory without an
approved redistributable lock record and committed license evidence.
