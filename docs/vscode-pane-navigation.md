<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# Navigér mellem terminal og editor i VS Code med Ctrl+h/j/k/l

Dette dokument viser, hvordan du flytter fokus mellem VS Code's paneler
(editor, terminal, sidebar) med de samme taster, som bruges til vinduesskift i
Neovim. Så har du én vane på tværs af begge editorer.

---

## Idéen

VS Code har fire kommandoer, der flytter fokus til det panel, der ligger
**fysisk i den retning**:

| Tast     | Kommando                              |
| -------- | ------------------------------------- |
| `Ctrl+h` | `workbench.action.navigateLeft`       |
| `Ctrl+j` | `workbench.action.navigateDown`       |
| `Ctrl+k` | `workbench.action.navigateUp`         |
| `Ctrl+l` | `workbench.action.navigateRight`      |

Du behøver altså ikke en genvej pr. panel. Står du i terminalen, flytter
`Ctrl+k` dig op i dokumentet ovenover. Det virker også mellem editor-splits og
terminal-splits.

---

## Opsætning

Tilføj følgende til `~/.config/Code/User/keybindings.json` (opret filen, hvis
den ikke findes):

```jsonc
[
  // Fra editoren (kun når Vim ikke er i Insert, så Ctrl+h stadig er backspace dér)
  { "key": "ctrl+h", "command": "workbench.action.navigateLeft",  "when": "editorTextFocus && vim.mode != 'Insert'" },
  { "key": "ctrl+j", "command": "workbench.action.navigateDown",  "when": "editorTextFocus && vim.mode != 'Insert'" },
  { "key": "ctrl+k", "command": "workbench.action.navigateUp",    "when": "editorTextFocus && vim.mode != 'Insert'" },
  { "key": "ctrl+l", "command": "workbench.action.navigateRight", "when": "editorTextFocus && vim.mode != 'Insert'" },

  // Fra terminalen
  { "key": "ctrl+h", "command": "workbench.action.navigateLeft",  "when": "terminalFocus" },
  { "key": "ctrl+j", "command": "workbench.action.navigateDown",  "when": "terminalFocus" },
  { "key": "ctrl+k", "command": "workbench.action.navigateUp",    "when": "terminalFocus" },
  { "key": "ctrl+l", "command": "workbench.action.navigateRight", "when": "terminalFocus" }
]
```

---

## Hvorfor `when`-betingelserne?

### `vim.mode != 'Insert'`

Med VSCodeVim-extension'en sletter `Ctrl+h` et tegn i insert-mode. Dine egne
keybindings vinder over extension'ens, så uden betingelsen ville du overtage
tasten i **alle** modes. Betingelsen sørger for, at navigationen kun virker i
normal-, visual- og andre modes.

### `terminalFocus`

Når en tast er bundet til en workbench-kommando, fanger VS Code den, før
shellen (zsh) ser den. Det er det, der får navigationen til at virke fra
terminalen.

---

## Hvad koster det?

I terminalen mister du disse shell-genveje:

| Tast     | Normalt i zsh         | Alternativ           |
| -------- | --------------------- | -------------------- |
| `Ctrl+l` | Rydder skærmen        | Skriv `clear`        |
| `Ctrl+k` | Sletter resten af linjen | Sjældent brugt    |
| `Ctrl+h` | Backspace             | Brug Backspace-tasten |
| `Ctrl+j` | Linjeskift            | Brug Enter           |

I praksis er det kun `Ctrl+l`, man savner.

---

## Indbyggede alternativer uden opsætning

Hopper du kun mellem én terminal og én editor, kan du nøjes med VS Code's
standardgenveje:

- ``Ctrl+` `` skifter fokus til og fra terminalen.
- `Ctrl+1` sætter fokus på den første editor-gruppe.

De bliver besværlige, så snart du har flere splits. Her er `navigate*` bedre.
