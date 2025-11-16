{ lib
, stdenv
, fetchFromGitHub
, gradle
, nodejs
, zulu25
, makeWrapper
, buildNpmPackage
}:

let
  src = ./.;

  frontend = buildNpmPackage {
    pname = "booklore-ui";
    version = "0.0.40";
   
    src = ./booklore-ui;
    
    # to get this hash, run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps ./booklore-ui/package-lock.json"
    npmDepsHash = "sha256-QIylVk2Q13ilatrpWD6oWYPzMA2SOIFUPzRajJuHi+w=";

    npmBuildScript = "build";
    npmBuildFlags = [ "--" "--configuration=production" ];

    installPhase = ''
      runHook preInstall
      
      mkdir -p $out
      cp -r dist/booklore/* $out/
      
      runHook postInstall
    '';
  };

in

stdenv.mkDerivation rec {
  pname = "booklore";
  version = "0.0.40";
  inherit src;

  nativeBuildInputs = [ gradle zulu25 makeWrapper ];

  buildPhase = ''
    runHook preBuild

    echo "Building backend..."
    export GRADLE_USER_HOME=$(mktemp -d)
    cd booklore-api
    chmod +x gradlew
    ./gradlew build -x test --no-daemon
    cd ..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,lib,share/booklore/static}
    
    cp booklore-api/build/libs/*-SNAPSHOT.jar $out/lib/
    
    cp -r ${frontend}/* $out/share/booklore/static/
    
    JAR_FILE=$(ls booklore-api/build/libs/*-SNAPSHOT.jar | head -n1)
    JAR_NAME=$(basename "$JAR_FILE")
    makeWrapper ${zulu25}/bin/java $out/bin/booklore \
      --add-flags "-jar $out/lib/$JAR_NAME"
    
    runHook postInstall
  '';

    # to allow network access, temporary since it doesnt allow sandbox
  __noChroot = true;
}
