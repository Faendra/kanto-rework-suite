# CP3D01A — sandbox module-loading correction

Status: IMPLEMENTED / RUNTIME NOT TESTED
Branch: `experiment/sol-3dworld-hd2d`
Parent checkpoint: CP3D01

## Defect found during static audit

CP3D00 and the first CP3D01 commit used ordinary Lua `require("sol3d....")` for files authored inside the mod package.

That is not Gen1Recomp's supported multi-file mod contract. The v0.2.32 sandbox exposes a guarded `require` for engine/allowed modules, while mod-owned source is expected to be addressed through `mod:read(...)` and compiled with the sandboxed `load(...)` function. Relying on host `package.path` would make an installed package fail or depend on the developer checkout layout.

## Correction

`main.lua` now owns a tiny per-mod module loader:

1. source is read with `mod:read(path)`;
2. source is compiled by the sandbox-provided `load`;
3. local modules are cached by logical name;
4. while a local chunk executes, this mod's sandbox `require` is temporarily wrapped so already-loaded local modules resolve from the cache;
5. all other module requests delegate to the original sandbox require;
6. the original require is restored even when the local chunk raises;
7. a missing, uncompilable, failing or nil-returning local module fails the mod load with an attributed error.

No `package`, `io`, `love.filesystem`, host path or `engine_internals` access was added.

## Consequence

The previously identified loader defect is corrected in source. Runtime validation remains mandatory; this checkpoint does not claim that Gen1Recomp v0.2.32 has successfully booted the package yet.
