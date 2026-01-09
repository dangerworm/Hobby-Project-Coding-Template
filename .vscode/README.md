# Visual Studio Code Repository Settings

I use Visual Studio Code for a lot of front end and infrastructure development,
and these config files configure its behaviour within the repository.

- **extensions.json** suggests extensions I've not installed
- **settings.json** is a workspace-specific configuration file

For those unfamiliar with it, the override order from lowest priority to highest
priority is:

- Default settings (VS Code itself)

  - These are the built-ins shipped with VS Code. They exist mainly to be
    overruled.

- User settings (global)

  - Your personal preferences, usually in `settings.json` under your user
    profile. These apply to every project unless something closer overrides
    them.

- Remote / Profile user settings (if applicable)

  - If you’re using a Remote (WSL, SSH, container) or a Settings Profile, those
    user settings override your local user settings for that context only.

- Workspace settings stored in `.vscode/settings.json` in the repository

  - These override user settings for that project and are how teams enforce
    consistency.

- Workspace folder settings (multi-root workspaces)

  - If you have a `.code-workspace` with multiple folders, each folder can have
    its own `.vscode/settings.json`. These override the workspace-level settings
    for that folder only.

- Language-specific settings

  - Within any of the user/workspace settings files you can also set
    language-specific rules.
  - These override all of the above, but only for that language, and still
    respect the same hierarchy (user -> workspace -> folder).
  - Example settings.json:

    ```json
    "[csharp]": {
      "editor.wordWrap": "wordWrapColumn",
      "editor.wordWrapColumn": 100,
      "editor.tabSize": 24
    }
    ```
