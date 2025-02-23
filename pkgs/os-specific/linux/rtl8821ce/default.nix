{ lib
, stdenv
, fetchFromGitHub
, fetchpatch
, kernel
, bc
}:

stdenv.mkDerivation rec {
  pname = "rtl8821ce";
  version = "${kernel.version}-unstable-2021-11-19";

  src = fetchFromGitHub {
    owner = "tomaspinho";
    repo = "rtl8821ce";
    rev = "ca204c60724d23ab10244f920d4e50759ed1affb";
    sha256 = "18ma8a8h1l90dss0k6al7q6plwr57jc9g67p22g9917k1jfbhm97";
  };

  # Fixes the build on kernel >= 5.17. Can be removed once https://github.com/tomaspinho/rtl8821ce/pull/267 is merged
  patches = [(fetchpatch {
    url = "https://github.com/tomaspinho/rtl8821ce/commit/7b9e55df64b10fed785f22df9f36ed4a30b59d0e.patch";
    sha256 = "sha256-mpAWOG1aXsklGuDbrRB9Vd36mgeCdctKQaWuuoqEEp0=";
  })];

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = [ bc ] ++ kernel.moduleBuildDependencies;
  makeFlags = kernel.makeFlags;

  prePatch = ''
    substituteInPlace ./Makefile \
      --replace /lib/modules/ "${kernel.dev}/lib/modules/" \
      --replace '$(shell uname -r)' "${kernel.modDirVersion}" \
      --replace /sbin/depmod \# \
      --replace '$(MODDESTDIR)' "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  preInstall = ''
    mkdir -p "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Realtek rtl8821ce driver";
    homepage = "https://github.com/tomaspinho/rtl8821ce";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    broken = stdenv.isAarch64;
    maintainers = with maintainers; [ hhm ivar ];
  };
}
