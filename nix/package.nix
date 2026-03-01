{
  lib,
  stdenv,
  makeWrapper,
  bash,
  coreutils,
  curl,
  gawk,
  gnugrep,
  jq,
  util-linux,
  version ? "0.1.0",
}:

stdenv.mkDerivation {
  pname = "nbx";
  inherit version;

  src = ../.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp "$src/nbx.sh" $out/bin/nbx
    chmod +x $out/bin/nbx

    substituteInPlace $out/bin/nbx \
      --replace 'VERSION="''${VERSION:-dev}"' 'VERSION="${version}"'

    patchShebangs $out/bin

    wrapProgram $out/bin/nbx --prefix PATH : ${
      lib.makeBinPath [
        bash
        coreutils
        curl
        gawk
        gnugrep
        jq
        util-linux
      ]
    }
  '';

  meta = with lib; {
    description = "CLI for NetBox REST and GraphQL APIs";
    homepage = "https://github.com/pschmitt/nbx";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ pschmitt ];
    mainProgram = "nbx";
    platforms = platforms.all;
  };
}
