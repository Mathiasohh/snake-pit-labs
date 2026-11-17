# Neovim: "No C compiler found!"

Dette dokument forklarer, hvorfor Neovim meldte fejl ved opstart i vores
Debian-devcontainer, og hvordan det blev rettet.

Filen det handler om:

- [Dockerfile.debian](../.devcontainer/debian/Dockerfile.debian): opskriften på,
  hvordan containeren bygges.

---

## Hvad vi så

Når `nvim` startede, kom denne fejl:

```text
Error in /home/container-user/.config/nvim/init.lua:
No C compiler found! "cc", "gcc", "clang", "cl", "zig" are not executable.
No C compiler found! "cc", "gcc", "clang", "cl", "zig" are not executable.
```

## Hvad der var galt

### Neovim selv var ikke problemet

Neovim installeres som et færdigbygget program, der hentes direkte fra GitHub.
Det kræver ingen compiler, og `nvim` kunne sagtens starte.

### Det var et plugin, der skulle bygge noget

Vores Neovim-opsætning (`init.lua` fra dotfiles) bruger pluginet
**nvim-treesitter**. Det giver bedre syntax highlighting ved at bruge en
*parser* for hvert sprog (Python, Lua, Bash …).

Parserne leveres ikke færdige. Treesitter henter kildekoden, som er skrevet i C,
og kompilerer den på din egen maskine. Til det skal der bruges en
**C-compiler**: et program, der oversætter C-kode til noget, computeren kan
køre. Treesitter leder efter en af `cc`, `gcc`, `clang`, `cl` eller `zig`.

Fejlen står to gange, fordi den kommer én gang for hver parser, der forsøges
bygget.

### Hvorfor der ikke var nogen compiler

To ting gjorde, at der ikke fandtes nogen compiler i containeren:

1. **Vi bygger på `debian:trixie-*-slim`.** "Slim"-varianten er skåret ned til
   det mest nødvendige for at holde den lille. Build-værktøjer er ikke med.
2. **Vi installerer med `--no-install-recommends`.** Det forhindrer `apt` i at
   trække ekstra "anbefalede" pakker med, så heller ikke dén vej kom der en
   compiler ind.

Du kan selv tjekke det i en terminal i containeren:

```sh
which cc gcc clang
# cc not found
# gcc not found
# clang not found
```

---

## Rettelsen

Tre pakker er tilføjet til `apt-get install`-listen i `Dockerfile.debian`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gcc \
    libc6-dev \
    make \
    openssh-client \
    ...
```

| Pakke | Hvorfor |
| --- | --- |
| `gcc` | Selve C-compileren. Giver også kommandoen `cc`. |
| `libc6-dev` | Header-filer som `stdlib.h` og `string.h`. Uden dem kan `gcc` findes, men kompileringen fejler alligevel. |
| `make` | Bruges af nogle plugins (fx `telescope-fzf-native`) til at styre bygningen. |

Vi har valgt de tre pakker i stedet for `build-essential`. Den giver også
`g++`, `dpkg-dev` og en del andet, som gør imaget større, uden at Neovim har
brug for det.

### Sådan får du rettelsen

Ændringer i Dockerfilen virker først, når containeren bygges igen. Kør
**Dev Containers: Rebuild Container** i VS Code. Tjek bagefter:

```sh
gcc --version
```

Start derefter `nvim` og kør `:checkhealth nvim-treesitter` for at se, om
parserne bliver bygget.

---

## Hvis fejlen stadig kommer

Den nyere `main`-branch af nvim-treesitter (beregnet til Neovim 0.12) bruger
også programmet **`tree-sitter` CLI** til at bygge parsere. Melder
`:checkhealth nvim-treesitter` at `tree-sitter` mangler, kan det installeres
med npm, som vi allerede har via nvm:

```sh
npm install -g tree-sitter-cli
```

Skal det være permanent, hører kommandoen hjemme i post-create scriptet
([post-create.sh](../.devcontainer/scripts/post-create.sh)), efter at Node er
sat op.

## Lærdom at tage med

- **Slim images mangler build-værktøjer.** Skal noget kompileres i containeren,
  skal compileren installeres eksplicit.
- **Et program kan virke, mens dets plugins ikke gør.** Læs fejlmeldingen
  grundigt: her kom den fra `init.lua`, altså fra opsætningen, ikke fra Neovim
  selv.
