<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# Hvorfor devcontaineren ikke ville starte, og hvordan den blev rettet

Dette dokument forklarer fem fejl i vores Debian-devcontainer. Det er skrevet til dig, der er ny i Docker og Linux, så vi starter med lidt baggrund.

Filerne det handler om:

- [Dockerfile.debian](../.devcontainer/debian/Dockerfile.debian): opskriften på, hvordan containeren bygges.
- [docker-compose.yml](../.devcontainer/debian/docker-compose.yml): beskriver, hvordan containeren startes (fx hvilke mapper den får adgang til).

---

## Lidt baggrund først

### Hvad er en Dockerfile?

En Dockerfile er en opskrift, som Docker følger linje for linje for at bygge et *image*: en færdigpakket "computer" med styresystem og programmer. Hver `RUN`-linje er en kommando, der køres under bygningen, præcis som hvis du skrev den i en terminal.

Det vigtige er, at **ingen sidder ved tastaturet** under bygningen. Hvis en kommando stiller et spørgsmål og venter på svar, går det galt.

### Hvad er apt og dpkg?

På Debian (det Linux-system vores container bygger på) installeres programmer med `apt-get install <navn>`. Under motorhjelmen er det programmet `dpkg`, der pakker pakkerne ud og sætter dem op.

### Hvad er sudo?

`sudo` lader en almindelig bruger køre kommandoer som administrator ("root"). Hvem der må bruge `sudo`, står i filen `/etc/sudoers`.

---

## Fejl 1: Installationen af sudo gik i stå

### Hvad vi så

Bygningen stoppede med denne fejl:

```text
*** sudoers (Y/I/N/O/D/Z) [default=N] ?
dpkg: error processing package sudo (--configure):
 end of file on stdin at conffile prompt
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

### Hvad der skete, trin for trin

Dockerfilen gjorde tingene i denne rækkefølge:

1. Opret brugeren `container-user`.
2. Skriv en linje i `/etc/sudoers`, der giver brugeren lov til at bruge `sudo`.
3. Installér programmer, **herunder `sudo`**.

Problemet ligger mellem trin 2 og 3. Filen `/etc/sudoers` *hører til* `sudo`-pakken, for pakken har sin egen udgave af den. Da `sudo` blev installeret i trin 3, fandt `dpkg` en `/etc/sudoers`, som allerede eksisterede og så anderledes ud end pakkens.

I den situation stopper `dpkg` og spørger: *"Der ligger allerede en ændret version af filen. Vil du beholde din eller bruge pakkens?"* (det er `Y/I/N/O/D/Z`-spørgsmålet).

Som nævnt sidder der ingen ved tastaturet under en Docker-bygning. `dpkg` fik intet svar ("end of file on stdin" betyder "der kom ikke noget input"), opgav og meldte fejl. Derfor fejlede hele bygningen.

> **Sammenligning:** Det svarer til, at du lægger dine egne papirer i en mappe, før flyttefolkene kommer med den samme mappe. Flyttefolkene ved ikke, om de skal smide dine papirer ud eller ej, og de kan ikke ringe til dig.

### Rettelsen

To ændringer:

1. **Byt om på rækkefølgen:** Installér programmerne først og opret brugeren bagefter.
2. **Skriv ikke i `/etc/sudoers`.** Læg i stedet reglen i sin egen lille fil, `/etc/sudoers.d/container-user`. Mappen `/etc/sudoers.d/` findes netop til det formål. `sudo` læser automatisk alle filer derinde, og pakkens egen `/etc/sudoers` forbliver uændret. Så har `dpkg` aldrig grund til at spørge om noget, heller ikke når `sudo` opdateres senere.

```dockerfile
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
chmod 0440 /etc/sudoers.d/$USERNAME
```

`chmod 0440` gør filen skrivebeskyttet. `sudo` nægter at bruge regel-filer, som andre kan ændre i, af sikkerhedshensyn.

---

## Fejl 2: Brugerens shell fandtes ikke

### Hvad der var galt

En *shell* er det program, der tager imod dine kommandoer i terminalen (fx `bash` eller `zsh`). Brugeren blev oprettet med `--shell /bin/zsh`, altså "når brugeren åbner en terminal, så start zsh". Men `zsh` blev aldrig installeret.

Linux siger ikke fra, når brugeren oprettes. Fejlen viser sig først senere, når brugeren prøver at åbne en terminal, og programmet ikke findes.

### Rettelsen

`zsh` er tilføjet til listen over programmer, der installeres.

---

## Fejl 3: Mappen til nvm fandtes ikke

### Hvad vi så

Da fejl 1 var rettet, kom bygningen længere og stoppede her:

```text
You have $NVM_DIR set to "/usr/local/bin/.nvm", but that directory does not exist.
```

### Hvad der var galt

`nvm` er et værktøj til at installere forskellige versioner af Node.js. Dockerfilen fortæller nvm, at den skal installeres i mappen `/usr/local/bin/.nvm` (via variablen `NVM_DIR`). nvm's installationsscript kræver dog, at mappen **allerede findes**. Den opretter den ikke selv.

### Rettelsen

Opret mappen lige før installationen:

```dockerfile
RUN mkdir -p "$NVM_DIR" && curl -fsSL https://.../install.sh | ... bash
```

`mkdir -p` betyder "opret mappen, og gør intet, hvis den allerede findes".

---

## Fejl 4: En variabel, der ikke virkede i PATH

### Hvad der var galt

`PATH` er listen over mapper, hvor systemet leder efter programmer, når du skriver et kommandonavn. Dockerfilen havde:

```dockerfile
ENV USERNAME=container-user \
    LOCAL_BIN=/usr/local/bin \
    PATH="/home/container-user/.local/bin:/${LOCAL_BIN}:$PATH"
```

Det ser rigtigt ud, men i en Dockerfile kan en variabel **ikke bruges i den samme `ENV`-linje**, som den bliver defineret i. `${LOCAL_BIN}` var derfor tom, og PATH fik bare `/` (roden af filsystemet) tilføjet. Docker advarede også om det: `UndefinedVar: Usage of undefined variable '$LOCAL_BIN'`.

### Rettelsen

Den del er fjernet. `/usr/local/bin` står allerede i PATH som standard på Debian, så der skulle slet ikke tilføjes noget.

---

## Fejl 5: `~` i docker-compose.yml

### Hvad der var galt

I `docker-compose.yml` står der, hvilke *volumes* (gemte mapper, der overlever, når containeren slettes) der skal sættes ind i containeren, og hvor de skal placeres:

```yaml
- gemini:~/.gemini
```

I en terminal betyder `~` "min hjemmemappe". Den oversættelse foretages af shellen, ikke af Docker. Docker Compose ved ikke, hvad `~` betyder inde i containeren (hvis hjemmemappe? Compose kender ikke brugeren). Stien inde i containeren skal derfor skrives helt ud.

### Rettelsen

```yaml
- gemini:/home/container-user/.gemini
- claude:/home/container-user/.claude
- ssh:/home/container-user/.ssh
- ssh-template:/home/container-user/.sshtemplate
```

---

## Hvordan det blev testet

Imaget blev bygget fra `Dockerfile.debian`, og derefter blev følgende kontrolleret inde i containeren:

- Brugeren `container-user` findes og har `/bin/zsh` som shell.
- Filen `/etc/sudoers.d/container-user` findes, og `sudo` virker uden adgangskode.
- nvm er installeret (`/usr/local/bin/.nvm/nvm.sh` findes).

## Lærdom at tage med

- **Ingen interaktion under build.** Alt i en Dockerfile skal kunne køre uden, at nogen svarer på spørgsmål.
- **Rækkefølgen betyder noget.** Installér pakkerne, før du ændrer i deres filer, eller undgå helt at ændre i dem.
- **Brug `.d`-mapper.** Mange programmer (`sudo`, `apt`, `ssh` …) har en `<navn>.d/`-mappe til dine egne tilføjelser, så du ikke behøver at redigere pakkens egne filer.
- **Læs fejlmeldingen nedefra og op.** Den sidste linje siger bare "det fejlede". Den egentlige årsag står længere oppe.
