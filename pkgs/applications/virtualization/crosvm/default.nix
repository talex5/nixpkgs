{ stdenv, lib, rust, rustPlatform, fetchgit
, meson, ninja, pkg-config, python3, wayland-scanner
, libcap, libdrm, libepoxy, libglvnd, minijail, wayland, wayland-protocols, xorg
, linux, mesa
}:

let

  upstreamInfo = with builtins; fromJSON (readFile ./upstream-info.json);

  arch = with stdenv.hostPlatform;
    if isAarch64 then "arm"
    else if isx86_64 then "x86_64"
    else throw "no seccomp policy files available for host platform";

  rustTarget = rust.toRustTarget stdenv.hostPlatform;
  rustArch = lib.head (builtins.match "([^-]*).*" rustTarget);

  defaultMesonFlags = (stdenv.mkDerivation { name = "meson-cross-hack"; mesonFlags = []; }).mesonFlags;
  mesonCrossFile = with builtins;
    head (head (map (match "--cross-file=(.*)") defaultMesonFlags ++ [ [ null ] ]));

in

  rustPlatform.buildRustPackage rec {
    pname = "crosvm";
    inherit (upstreamInfo) version;

    src = fetchgit (builtins.removeAttrs upstreamInfo.src [ "date" "path" ]);

    patches = [
      ./default-seccomp-policy-dir.diff
      ./rutabaga_gfx-don-t-clobber-PKG_CONFIG_PATH.patch
      ./fix-gui-jail.patch
      ./slow-fences.patch
      ./no-gpu-window.patch
      ./fix-keymaps.patch
    ];

    cargoLock.lockFile = ./Cargo.lock;

    nativeBuildInputs = [ meson ninja pkg-config python3 wayland-scanner ];

    buildInputs = [
      libcap libdrm libepoxy libglvnd minijail wayland wayland-protocols
      xorg.libX11 mesa
    ];

    postPatch = ''
      cp ${./Cargo.lock} Cargo.lock
      sed -i "s|/usr/share/policy/crosvm/|$out/share/policy/|g" \
             seccomp/*/*.policy
      substituteInPlace third_party/minigbm/common.mk --replace /bin/ ""
      sed -i '/fn main() {/a println!("cargo:rustc-link-lib=X11");' gpu_display/build.rs

      # rutabaga_gfx/build.rs tests for the existence of this.
      touch third_party/{minigbm,virglrenderer}/.git
    '';

    preBuild = ''
      export DEFAULT_SECCOMP_POLICY_DIR=$out/share/policy
    '' + lib.optionalString (mesonCrossFile != null) ''
      dataDir="$(mktemp -d)"
      mkdir -p "$dataDir/meson/cross"
      ln -s ${mesonCrossFile} "$dataDir/meson/cross/${rustArch}"
      export XDG_DATA_DIRS="$dataDir"
    '';

    dontUseNinjaBuild = true;
    dontUseNinjaInstall = true;

    buildFeatures = [ "default" "virgl_renderer" "virgl_renderer_next" ];

    postInstall = ''
      mkdir -p $out/share/policy/
      cp seccomp/${arch}/* $out/share/policy/
    '';

    CROSVM_CARGO_TEST_KERNEL_BINARY =
      lib.optionalString (stdenv.buildPlatform == stdenv.hostPlatform)
        "${linux}/${stdenv.hostPlatform.linux-kernel.target}";

    passthru.updateScript = ./update.py;

    meta = with lib; {
      description = "A secure virtual machine monitor for KVM";
      homepage = "https://chromium.googlesource.com/chromiumos/platform/crosvm/";
      maintainers = with maintainers; [ qyliss ];
      license = licenses.bsd3;
      platforms = [ "aarch64-linux" "x86_64-linux" ];
    };
  }
