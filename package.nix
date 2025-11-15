{ lib
, stdenv
, fetchFromGitHub
, gradle
, nodejs
, zulu25
, makeWrapper
, nginx
}:

stdenv.mkDerivation rec {
  pname = "booklore";
  version = "0.0.40";

  src = ./.;

  nativeBuildInputs = [
    gradle
    nodejs
    zulu25
    makeWrapper
  ];

  buildPhase = ''
    export GRADLE_USER_HOME=$TMPDIR/gradle
    export HOME=$TMPDIR
    export npm_config_cache=$TMPDIR/npm-cache
    
    # Build Angular frontend
    echo "building frontend"
    cd booklore-ui
    npm config set registry http://registry.npmjs.org/
    npm install --force 
    patchShebangs node_modules
    npm run build --configuration=production
    cd ..
    
    # Build Spring Boot backend
    cd booklore-api
    chmod +x gradlew
    ./gradlew clean build -x test --no-daemon
    cd ..
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,share/booklore/static}
    
    # Install the Spring Boot JAR
    cp booklore-api/build/libs/*.jar $out/lib/
    
    # Install the frontend
    cp -r booklore-ui/dist/booklore/* $out/share/booklore/static/
    
    # Create executable
    makeWrapper ${zulu25}/bin/java $out/bin/booklore \
      --add-flags "-jar $out/lib/booklore-api.jar"
  '';


  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = lib.fakeSha256;
}
