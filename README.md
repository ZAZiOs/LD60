# tech_plague

A 2D game built with [LÖVE](https://love2d.org/) (Love2D).

## Requirements

- [LÖVE](https://love2d.org/) 11.5+ installed and available in your `PATH`.
- [makelove](https://github.com/pfirsich/makelove) installed and available in your `PATH` (only required for building release packages).

## Running the game

From the project root:

```bash
love .
```

## VS Code

`.vscode/` contains launch and build configurations.
- Run/Debug: `Ctrl+Shift+D` -> select **Debug** or **Release**.
- Build: `Ctrl+Shift+B`.

## Build Release Packages

Uses **makelove** for **win64** and **lovejs** targets.

1. Copy the template and set your LÖVE binary path:

    ```bash
    cp make_all.toml.example make_all.toml
    ```

    Edit `make_all.toml`:

    ```toml
    [win64]
    love_binaries = "C:/path/to/love2d" # <-- required for win64 builds
    ```
    (Note: `make_all.toml` is git-ignored since the path is machine-specific).

2. Run the build:

    ```bash
    makelove --config make_all.toml
    ```

    Output goes to `bin/` (git-ignored).

## Documentation

- [Core Library Documentation (docs/CORE.md)](docs/CORE.md) — подробное руководство по всем модулям ядра (`src/core/`): сцены, вьюпорт, звук, анимации, локализация, шрифты, шина событий.

## Project Structure

```text
.
├── main.lua              # Entry point
├── conf.lua              # LÖVE config
├── src/                  # Game source
│   ├── core/             # Framework modules (see docs/CORE.md)
│   ├── scenes/           # Game scenes
│   ├── locales/          # Translations (ru.json, en.json)
│   └── lib/              # Third-party utilities (json, etc.)
├── docs/                 # Project documentation
├── assets/               # Sprites, fonts, audio
├── .vscode/              # Editor tasks
├── make_all.toml.example # Local build template
└── bin/                  # Build output (ignored)
```

