# Remote GPU development on lebpc39

lebpc39 has an RTX A4500 and no monitor attached. `servers/lebpc39/remote.nix`
sets it up so you can SSH in, run a full GPU-accelerated desktop session over
VNC, and use apps like Napari (or run ML pipelines) against the same GPU.

## Architecture

Two separate X servers are involved — the standard VirtualGL pattern:

- **`:0` — the real GPU X server.** A headless Xorg process bound directly to
  the A4500 (`systemd.services.gpu-xorg`, always running, started at boot).
  Nothing connects to this directly; it exists purely so VirtualGL has a real
  GPU context to render into. There's no monitor, so it's configured with
  `AllowEmptyInitialConfiguration` / `UseDisplayDevice none`.
- **`:1` — the VNC session.** A TigerVNC (`Xvnc`) session running icewm,
  started on demand via a systemd **user** service
  (`systemctl --user start tigervnc`). This is what you actually connect a
  VNC client to.

Apps launched inside the `:1` session with `vglrun -d :0 <command>` have
their OpenGL calls redirected to the real GPU on `:0`, rendered there, and
the resulting frames shipped back into the VNC session. CUDA/ML workloads
don't need `vglrun` at all — they talk to the GPU directly through the CUDA
driver regardless of which X session (if any) they're launched from, and run
concurrently with anything using VirtualGL (the GPU scheduler time-slices
between contexts; the only real constraint is shared VRAM).

## One-time setup (on lebpc39, after deploying)

```console
sudo mkdir -p /etc/tigervnc/secrets
sudo vncpasswd /etc/tigervnc/secrets/douglass.password
sudo chown douglass /etc/tigervnc/secrets/douglass.password
loginctl enable-linger douglass
```

The `chown` matters: the VNC session runs as `douglass` and needs to read
that password file. `enable-linger` lets the on-demand VNC session keep
running after you close the SSH connection that started it.

See the README's "Out-of-band files" section for how this fits the repo's
general secrets convention.

## Day-to-day usage

```console
ssh -L 5901:localhost:5901 douglass@lebpc39
systemctl --user start tigervnc   # if not already running
```

Then point a VNC client at `localhost:5901` (TigerVNC's own viewer is
recommended for best protocol compatibility: `sudo apt install
tigervnc-viewer`, then `xtigervncviewer localhost:5901`).

Inside the session, right-click the desktop for icewm's menu — **XTerm**
opens a terminal, **GLX Info (vglrun)** runs a quick sanity check that
prints the GPU being used for rendering. From a terminal:

```console
vglrun -d :0 python -m napari
```

VNC is intentionally **not** exposed on the LAN — `Xvnc` binds to
`localhost` only, and no firewall port is opened. The SSH tunnel is the only
way in.

## Verifying it's working

```console
vglrun -d :0 glxinfo | grep "OpenGL renderer"
```

should report `NVIDIA RTX A4500...` with `direct rendering: Yes`. If it
reports `llvmpipe` instead, VirtualGL isn't reaching the GPU X server —
check `systemctl status gpu-xorg` and `douglass`'s group membership
(`vglusers`, `video`, `render`).

## Troubleshooting notes from getting this running

A few non-obvious things came up bringing this up the first time, in case
`gpu-xorg.service` needs touching again:

- **`Xorg :0` failing with "no screens found"**: launching `Xorg` directly
  (as `gpu-xorg.service` does) bypasses the `ModulePath` wiring that
  `services.xserver` normally sets up, so `nvidia_drv.so` was never found.
  The fix is the `Files` section in `gpuXorgConf` pointing `ModulePath` at
  `${config.hardware.nvidia.package.bin}/lib/xorg/modules`, listed *ahead*
  of `xorg-server`'s own modules path — this mirrors what NixOS's own
  `nvidia.nix`/`xserver.nix` do internally (`modules = [ nvidia_x11.bin ]`).
- **No `Load "glx"` directive**: `nvidia_drv.so` loads its own GLX submodule
  (`glxserver_nvidia`) internally once it initializes. An explicit
  `Load "glx"` in the config would instead resolve to `xorg-server`'s Mesa
  `libglx.so` (the only file matching that name on the search path) and get
  in the way.
- **icewm's menu is empty by default**: unlike most window managers, icewm
  doesn't scan `$PATH` or `.desktop` files on its own — entries have to be
  listed explicitly in a menu file (`environment.etc."icewm/menu"` here).
  It's also only read once at icewm startup, so changes require
  `systemctl --user restart tigervnc` (which drops any active VNC
  connection — just reconnect your client after).
- **`pkgs.xorg.xorgserver`**: deprecated alias in this nixpkgs pin; use
  `pkgs.xorg-server` instead.
- **`pkgs.glxinfo`**: renamed to `pkgs.mesa-demos` (still provides the
  `glxinfo` binary).
