{ lib
, buildPythonApplication
, fetchFromGitHub
, wrapGAppsHook
, gobject-introspection
, imagemagick
, networkmanager
, pango
, webkitgtk
# Python libs
, protonvpn-nm-lib
, psutil
# Optionals
, withIndicator ? true
, libappindicator-gtk3 }:

buildPythonApplication rec {
  pname = "protonvpn-gui";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "ProtonVPN";
    repo = "linux-app";
    rev = "refs/tags/${version}";
    sha256 = "sha256-Od12qHiyXHu2JnjYV7amZz5xxL+eiWUVbcG5Tbcrr28=";
  };

  nativeBuildInputs = [
    gobject-introspection
    imagemagick
    wrapGAppsHook
  ];

  propagatedBuildInputs = [
    protonvpn-nm-lib
    psutil
  ];

  buildInputs = [
    # To avoid enabling strictDeps = false (#56943)
    gobject-introspection
    networkmanager
    pango
    webkitgtk
  ] ++ lib.optionals withIndicator [ libappindicator-gtk3 ];

  postInstall = ''
    # Setting icons
    for size in 16 32 48 64 72 96 128 192 512 1024; do
      mkdir -p $out/share/icons/hicolor/"$size"x"$size"/apps
      convert -resize $size'x'$size \
        protonvpn_gui/assets/icons/protonvpn-logo.png \
        $out/share/icons/hicolor/$size'x'$size/apps/protonvpn.png
    done

    install -Dm644 protonvpn.desktop -t $out/share/applications/
    substituteInPlace $out/share/applications/protonvpn.desktop \
      --replace 'protonvpn-logo' protonvpn
  '';

  # Project has a dummy test
  doCheck = false;

  meta = with lib; {
    description = "Official ProtonVPN Linux app";
    homepage = "https://github.com/ProtonVPN/linux-app";
    maintainers = with maintainers; [ wolfangaukang ];
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
