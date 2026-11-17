<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# Dotfiles i devcontaineren: minimum-pakker og opsætning

Dette dokument beskriver, hvad der skal til, for at VS Code automatisk installerer
[devcontainer-dotfiles](https://github.com/sukkergris/devcontainer-dotfiles) i
vores Debian-devcontainer, og hvordan man fejlsøger, når det ikke sker.

---

## Sådan virker det

Når VS Code opretter en devcontainer, kører den disse trin **inde i containeren**,
som `remoteUser` (`container-user`):

1. `git clone <dotfiles.repository> <dotfiles.targetPath>`
2. `cd <dotfiles.targetPath> && ./<dotfiles.installCommand>`
3. Opretter markøren `~/.devcontainer/.dotfilesMarker`

Findes markøren allerede, springes hele trinnet over. Derfor kræver en ændring
i dotfiles-indstillingerne altid **Dev Containers: Rebuild Container**.

Alle programmer, som `git clone` og `.install.sh` bruger, skal altså være
installeret i imaget **før** trinnet kører.

---

## VS Code user settings

Indstillingerne hører til i dine **user settings** på hosten
(`~/.config/Code/User/settings.json`), ikke i `devcontainer.json`:

```json
{
  "dotfiles.repository": "https://github.com/sukkergris/devcontainer-dotfiles.git",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": ".install.sh"
}
```

| Indstilling | Betydning |
| --- | --- |
| `dotfiles.repository` | Repoet, der klones. HTTPS kræver ingen nøgler, fordi repoet er offentligt. |
| `dotfiles.targetPath` | Hvor repoet klones hen i containeren. |
| `dotfiles.installCommand` | Scriptet i repoets rod, der køres efter clone. Filen hedder `.install.sh` (med punktum). |

### HTTPS eller SSH?

| URL | Ekstra krav |
| --- | --- |
| `https://github.com/...` | Ingen. Anbefalet. |
| `git@github.com:...` | `openssh-client` i imaget. VS Code videresender din host-SSH-agent (`SSH_AUTH_SOCK`), men programmet `ssh` skal findes i containeren. |

Uden `openssh-client` fejler en SSH-URL med det samme:

```text
error: cannot run ssh: No such file or directory
fatal: unable to fork
```

---

## Minimum-pakker

Testet i en ren `debian:trixie-20261027-slim` med en almindelig bruger og
HTTPS-URL:

| Pakke | Påkrævet | Hvorfor |
| --- | --- | --- |
| `git` | Ja | Kloner dotfiles-repoet, Oh My Zsh og Powerlevel10k. |
| `ca-certificates` | Ja | Uden den fejler alle HTTPS-kloninger. `-slim`-imaget har den ikke. |
| `stow` | Ja\* | Laver symlinks fra repoet ind i `$HOME`. |
| `sudo` (med NOPASSWD) | Kun hvis `stow` mangler | `.install.sh` forsøger selv at installere `stow` via `sudo apt-get`. |
| `openssh-client` | Kun ved SSH-URL | Se ovenfor. |
| `zsh` | Nej, ikke for installationen | Men dotfiles er bygget til zsh, så du skal bruge den som login-shell. |

\* Enten `stow` eller `sudo` uden password. Det sikreste er at installere `stow` direkte.

`bash`, `coreutils` og `grep`, som scriptet også bruger, er allerede med i Debian-basen.

### Testresultater

| Installerede pakker | Resultat |
| --- | --- |
| `ca-certificates git stow zsh` | ✓ Lykkes |
| `git stow` | ✗ `Problem with the SSL CA cert` |
| `ca-certificates stow` | ✗ `git: not found` |
| `ca-certificates git` | ✗ `Error: Failed to install stow.` |
| `ca-certificates git sudo` | ✓ Lykkes (stow installeres af scriptet) |

### I Dockerfilen

Det svarer til denne linje i [Dockerfile.debian](../.devcontainer/debian/Dockerfile.debian):

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openssh-client \
    stow \
    zsh \
    && rm -rf /var/lib/apt/lists/*
```

`openssh-client` kan udelades, hvis du kun bruger HTTPS. Vores Dockerfile har
den med alligevel, så `git push` over SSH også virker i containeren.

---

## Fejlsøgning: hvor er loggene?

En trin-for-trin-guide med et eksempel på et vellykket forløb findes i
[dotfiles-fejlsoegning.md](dotfiles-fejlsoegning.md).

| Hvad | Hvor |
| --- | --- |
| Hele container-opbygningen, inkl. `git clone` af dotfiles | Command Palette → **Dev Containers: Show Container Log**. Søg efter `dotfiles`. |
| Samme log, gemt på hosten | Command Palette → **Developer: Open Logs Folder** → `…/exthost*/ms-vscode-remote.remote-containers/remoteContainers-*.log` |
| Output fra `.install.sh` | `~/.devcontainer/logging/install.log` inde i containeren |
| Hvilke trin der er kørt | `ls -la ~/.devcontainer/` (markørfilerne og deres tidsstempler) |

### Fremgangsmåde

1. **Findes `~/dotfiles`?** Nej → clone fejlede. Se Container Log.
2. **Findes `~/.devcontainer/logging/install.log`?** Nej → `.install.sh` kørte
   aldrig. Det er en clone-fejl eller et forkert `installCommand`.
3. **Ja til begge** → fejlen er i selve `.install.sh`. Læs `install.log`.

### Afprøv uden VS Code

Inde i containeren kan du gentage præcis det, VS Code gør:

```sh
git clone https://github.com/sukkergris/devcontainer-dotfiles.git ~/dotfiles
cd ~/dotfiles && ./.install.sh
```

Eller test et minimum-image fra hosten:

```sh
docker run --rm debian:trixie-20261027-slim bash -c '
  apt-get update -qq && apt-get install -y -qq --no-install-recommends ca-certificates git stow zsh
  useradd -m u
  su u -c "git clone https://github.com/sukkergris/devcontainer-dotfiles.git ~/dotfiles && cd ~/dotfiles && ./.install.sh"'
```
