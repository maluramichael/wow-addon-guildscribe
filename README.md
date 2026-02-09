# GuildScribe

Automatically updates your guild note with profession information in World of Warcraft TBC Classic. Configurable format string with placeholders lets you customize exactly what appears in your note.

## Features

- **Auto-Update on Login**: Guild note is updated when you log in or reload
- **Auto-Update on Skill Change**: Note updates automatically when a profession levels up
- **Configurable Format String**: Use `{placeholder}` variables for professions, levels, and character info
- **Note Target**: Write to public note, officer note, or both
- **Debounced Updates**: Configurable delay (2-10s) to batch rapid skill changes
- **Live Preview**: Options panel shows formatted result with character count
- **Minimap Button**: Left-click to force update, right-click for options, tooltip shows professions
- **Guild Note Limit**: Automatically truncates to 31 characters with a warning

## Format Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `{prof1}` / `{prof2}` | `Alch` | Primary profession abbreviation |
| `{prof1_name}` / `{prof2_name}` | `Alchemy` | Full profession name |
| `{prof1_level}` / `{prof2_level}` | `375` | Current skill level |
| `{prof1_max}` / `{prof2_max}` | `375` | Max skill level |
| `{cooking}`, `{cooking_level}`, `{cooking_max}` | | Cooking info |
| `{firstaid}`, `{firstaid_level}`, `{firstaid_max}` | | First Aid info |
| `{fishing}`, `{fishing_level}`, `{fishing_max}` | | Fishing info |
| `{name}`, `{level}`, `{class}` | | Character info |

**Default format**: `{prof1} {prof1_level} / {prof2} {prof2_level}` → `Alch 375 / Herb 375`

## Slash Commands

- `/gs` or `/guildscribe` - Open options panel
- `/gs update` - Force update guild note
- `/gs preview` - Show formatted note in chat
- `/gs toggle` - Enable/disable the addon
- `/gs debug` - Toggle debug messages

## Requirements

- World of Warcraft TBC Classic (Interface 20505)
- Ace3 libraries (included via CurseForge packaging or OptionalDeps)
