This is an early Release of what I was working on. The mod isn't finished yet, more is to come and it will be reworked. Use it as a sneak peak to my mod. And DO READ compatibility section please :D

# Kanto Rework Suite 🎮

**A complete UI, UX and quality-of-life rework for Pokémon Red running on Gen1Recomp.**

Kanto Rework Suite started as the version of Pokémon Red I wanted to play myself: cleaner menus, better information visibility, less unnecessary navigation, stronger accessibility and better integration between mods.

I eventually decided to share it with the Gen1Recomp community.

The goal is not to completely transform Pokémon Red into another game. Kanto Rework tries to modernize the experience while keeping the original game recognizable.

> Kanto Rework Suite is currently developed primarily for **Windows PC at 16:9**.

---

## 🧩 Modular by design

Kanto Rework is not one giant mod.

The project is separated into modules with clearly defined responsibilities.

### 🧱 Kanto Rework Core

The shared foundation used by the other Kanto Rework modules.

It handles common services, configuration, accessibility foundations, shared contracts and integration with Gen1Recomp.

Core intentionally avoids owning screen-specific features.

---

### 🎨 Kanto Rework UI

The visual and interaction layer of the suite.

It redesigns major parts of Pokémon Red around a consistent interface built for modern PC interaction while staying faithful to the game's identity.

This includes areas such as:

- Main Menu
- Party
- Pokémon Summary
- Moves
- Bag
- PC
- Pokédex
- Map / Fly
- Options
- Controls
- Mods Manager
- Dialogues
- Battle information
- Field Actions
- Overlays

The UI supports keyboard and mouse as well as controller navigation where applicable.

Several visual themes are available:

- 🤍 Cream
- 🖤 Graphite
- 💜 Purple Night
- 🕹️ Retro

All themes share the same information architecture and accessibility requirements.

---

### ⚙️ Kanto Rework Gameplay

Gameplay contains the quality-of-life systems that change how the player interacts with the game without turning Core into a collection of unrelated features.

Examples include:

- Field Actions
- item shortcuts
- favorite items
- expanded inventory behavior
- PC improvements
- additional save management
- contextual gameplay information
- various navigation and interaction improvements

---

### 🔗 Kanto Rework Compatibility

Compatibility exists to help third-party mods coexist with Kanto Rework and, where safely possible, with each other.

Third-party mods are **not modified by Kanto Rework**.

Instead, Compatibility detects supported features and integrates them through Kanto Rework's menus and conflict-resolution systems.

When two mods provide the same feature, Kanto Rework can sometimes allow the player to choose which provider takes priority.

Examples already used by the project include selecting between different providers for:

- Pokémon battle sprites
- battle backgrounds
- overlapping visual systems

For example, a player may choose between **Gen1, Kanto Ascendant or a Voxel provider** for compatible sprite surfaces.

Compatibility is handled feature by feature rather than simply declaring an entire mod compatible or incompatible. fileciteturn0file1

---

# ✨ Major Features

## 📊 Better Pokémon information

Kanto Rework exposes much more useful information directly from the Pokémon interface.

This includes:

- DV information
- EV / Stat Experience information
- clearer Pokémon statistics
- move information
- status information
- progression information

The objective is to make information already relevant to the game readable without requiring external tools.

---

## ⚔️ Better battle information

Battle information has been expanded to make temporary stat changes easier to understand.

Instead of only knowing that a statistic increased or decreased, the UI can communicate the current battle modifiers and their practical effect where relevant, including effects related to:

- offensive statistics
- defensive statistics
- Speed
- Accuracy
- Evasion

This makes stat-changing moves and battle states much easier to follow.

---

## 💥 Battle Animations

**Battle Animations are now part of the Kanto Rework family of features.**

The system is being developed as another component of the overall battle presentation rather than as an isolated visual modification.

The objective is to improve the visual feedback and presentation of battles while keeping it coherent with the rest of the Kanto Rework experience.

As with the other Kanto Rework systems, compatibility with other mods affecting the same battle surfaces has to be handled explicitly rather than assumed.

---

## 💾 Four save slots

Kanto Rework expands save management beyond the traditional single-save workflow.

You can access:

- **4 save slots**
- save loading
- save deletion
- clearer save management directly from the interface

---

## 🔄 Save -> Restart -> Resume

Some Gen1Recomp mods require the game to restart after being enabled or disabled.

Kanto Rework includes an automatic restart workflow designed around this situation.

When a restart is required:

1. the active game is saved;
2. the current game/save context is preserved;
3. Gen1Recomp is restarted;
4. the saved game is resumed.

The restart mechanism has been validated through the LÖVE runtime and second-boot testing, although Windows/OpenGL qualification still requires real environment testing for each distributed build. fileciteturn0file2

---

## 🎒 Redesigned Bag

The inventory is reorganized into dedicated pockets instead of forcing everything into one large list.

The current organization includes:

- Medicine
- Poké Balls
- Battle Items
- Berries
- Other Items
- TMs & HMs
- Treasures
- Key Items

Additional quality-of-life systems include:

⭐ **Favorite Items**

Items can be marked as favorites for easier access.

⌨️ **Item Shortcuts**

Any item can be assigned to:

`CTRL + 1` through `CTRL + 9`

This is not restricted to a small predefined list of items.

---

## 📦 Expanded Pokémon PC

The Pokémon storage system is significantly expanded.

Boxes can hold up to:

**180 Pokémon per box**

The PC is also accessible directly through the Kanto Rework menu instead of requiring the player to physically interact with a PC every time they want to manage storage.

---

## 🌿 Field Actions

Field Actions reduce unnecessary menu navigation for common overworld actions.

Supported systems are designed around contextual actions such as HM-related interactions and other field abilities.

Manual interaction remains available where appropriate so the player is not forced into full automation.

---

## 🗺️ Map and Fly

Kanto Rework integrates Map and Fly into the redesigned interface.

The system is built around a dedicated Kanto map rather than treating Fly as an isolated menu command.

It can represent:

- the player's current location
- cities
- routes
- destinations
- destination availability
- Fly selection

---

## 📋 Optional information overlays

Kanto Rework also includes optional overlays intended to surface useful information without constantly opening menus.

Depending on the context, overlays can expose information such as:

- current Party
- Pokémon types
- wild encounter information
- captured status
- battle information
- capture-related information

Overlays can be configured according to where they should appear.

---

# ♿ Accessibility

Accessibility is a core design requirement rather than an optional visual extra.

Kanto Rework includes dedicated color-vision profiles:

- Standard
- Protanopia
- Deuteranopia
- Tritanopia

The default shortcut for cycling color-blind profiles is:

**F7**

Important information is not intended to depend solely on color.

UI states such as focus, selection, disabled controls and important gameplay information use additional visual distinctions whenever necessary.

---

# 🛠️ Mod settings belong in the Mods menu

Kanto Rework deliberately separates game settings from mod settings.

Third-party mod options should appear under:

**Mods -> Installed Mods -> [Mod]**

rather than filling the regular Options menu.

This is an intentional UX decision.

The Options screen is for the game and shared player preferences.

The Mods Manager is where mod-specific configuration belongs.

---

# 🔗 Compatibility philosophy

The objective of Compatibility is ambitious:

> Make as many reasonable mod combinations work together as possible without taking ownership away from the original mods.

But this is **not a promise that every mod will work with every other mod**.

Some mods fundamentally replace the same systems and cannot safely coexist.

This is particularly important with mods that are forks of each other or completely replace major rendering/gameplay systems.

Compatibility can sometimes resolve overlapping responsibilities by letting the player choose a provider.

It cannot magically combine two fundamentally incompatible implementations.

The formal Kanto Rework compatibility protocol distinguishes between loading, functional, presentation, save/resume and real-game compatibility instead of treating "compatible" as one binary state. fileciteturn0file1

---

# ⚠️ Read mod documentation before installing everything

Please do not install every mod you can find, enable all of them simultaneously and report that "Kanto Rework broke."

Some third-party mods are already incompatible with each other before Kanto Rework is involved.

Read the GitHub page and release information of each mod you install.

In particular, be careful when combining forks or multiple mods replacing the same major system.

---

# 🐛 How to identify an incompatible mod

If you use a large mod setup, test it progressively.

### 1. Start with Kanto Rework

Enable the Kanto Rework modules you want to use.

Launch the game and verify that everything works.

### 2. Add one third-party mod

Launch the game again and test it.

### 3. Add another one

If everything still works, continue.

### 4. Stop when something breaks

The last addition gives you a much smaller set of possible causes.

This is much more useful than enabling 30 mods simultaneously and trying to guess which one caused the problem.

---

# 📝 Reporting bugs

Please report reproducible bugs through **GitHub Issues**.

A useful report should contain:

- Gen1Recomp version
- Kanto Rework module versions
- exact third-party mod versions
- enabled Kanto Rework modules
- steps to reproduce
- expected behavior
- actual behavior
- screenshots when relevant
- logs when available
- which mod was added before the issue appeared, if applicable

GitHub Issues makes it considerably easier to determine whether a bug belongs to:

- Kanto Rework Core
- UI
- Gameplay
- Compatibility
- Gen1Recomp
- a third-party mod
- a specific combination of mods

Discord can be used for discussion.

Reproducible bugs should go to GitHub.

---

# 💻 Platform support

Kanto Rework is developed primarily for:

**Windows PC**

The layout I currently intend to officially support is:

**16:9**

I do not currently promise official support for:

- phones
- tablets
- handheld-specific interfaces
- 4:3
- 10:9
- ultrawide
- other aspect ratios
- other operating environments

Something working on another device does not automatically mean it is officially supported.

If it has not been tested, I will not claim that it has been tested.

---

# 🤝 Other devices and aspect ratios

If someone wants to adapt Kanto Rework to another platform, device or aspect ratio, contributions are welcome.

The important part is preserving:

- the project architecture
- accessibility
- input parity
- information hierarchy
- visual consistency
- maintainability

I simply do not intend to personally maintain every possible display configuration.

---

# ❤️ Project philosophy

Kanto Rework is first and foremost a mod I am making for myself.

I decided to share it because other people may enjoy the same kind of Pokémon Red experience.

That does not mean every requested feature will be implemented.

Suggestions are welcome.

Interesting compatibility requests are welcome.

Good accessibility improvements are welcome.

Useful feature ideas are welcome.

I may implement them.

I may decide they do not fit the project. :p

The objective is not to accumulate features indefinitely.

The objective is to build a coherent version of Pokémon Red that is:

- easier to navigate
- easier to read
- more informative
- more accessible
- more comfortable on PC
- easier to use with other mods
- faithful to the identity of Pokémon

And if you manage to break it... 🐛

Please open an Issue and tell me exactly how you did it. 😄
