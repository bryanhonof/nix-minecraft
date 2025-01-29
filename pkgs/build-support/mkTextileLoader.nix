{ lib
, fetchurl
, stdenvNoCC
, unzip
, zip
, graalvm-ce
, loaderName
, loaderVersion
, gameVersion
, serverLaunch
, mainClass ? ""
, libraries
, extraBuildPhase ? ""
}:

let
  inherit (builtins) head filter map match;

  lib_lock = lib.importJSON ./libraries.json;
  fetchedLibraries = lib.forEach libraries (l: fetchurl lib_lock.${l});
  asmVersion = head (head (filter (v: v != null) (map (match "org\\.ow2\\.asm:asm:([\.0-9]+)") libraries)));
in
stdenvNoCC.mkDerivation {
  pname = "${loaderName}-server-launch.jar";
  version = "${loaderName}-${loaderVersion}-${gameVersion}";
  nativeBuildInputs = [ unzip zip graalvm-ce ];

  libraries = fetchedLibraries;

  buildPhase = ''
    for i in $libraries; do
      unzip -o $i
    done

    cat > META-INF/MANIFEST.MF << EOF
    Manifest-Version: 1.0
    Main-Class: ${serverLaunch}
    Name: org/objectweb/asm/
    Implementation-Version: ${asmVersion}
    EOF

    ${
      if mainClass == "" then "" else ''
        cat > ${loaderName}-server-launch.properties << EOF
        launch.mainClass=${mainClass}
        EOF
      ''
    }

    ${extraBuildPhase}
  '';

  installPhase = ''
    rm -f META-INF/*.{SF,RSA,DSA}
    jar cmvf META-INF/MANIFEST.MF "server.jar" .
    cp server.jar "$out"
  '';

  phases = [ "buildPhase" "installPhase" ];

  passthru = {
    inherit loaderName loaderVersion gameVersion;
    propertyPrefix = {
      "fabric" = "fabric";
      "legacy-fabric" = "fabric";
      "quilt" = "loader";
    }.${loaderName};
  };
}
