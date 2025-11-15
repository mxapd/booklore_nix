# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.git
    pkgs.zulu25
    pkgs.nodejs_20
    pkgs.python3
    pkgs.mariadb
    pkgs.gradle
  ];

  shellHook = ''
    echo "=================================================="
    echo "  Welcome to the Booklore Development Shell!"
    echo "=================================================="
    
    # Setup MariaDB directories
    MYSQL_BASEDIR=${pkgs.mariadb}
    MYSQL_HOME="$PWD/.nix-shell/mysql"
    MYSQL_DATADIR="$MYSQL_HOME/data"
    export MYSQL_UNIX_PORT="$MYSQL_HOME/mysql.sock"
    MYSQL_PID_FILE="$MYSQL_HOME/mysql.pid"
    export TMPDIR="$PWD/.nix-shell/tmp"
    
    mkdir -p "$MYSQL_HOME"
    mkdir -p "$TMPDIR"
    
    alias mysql='mysql -u root --socket="$MYSQL_UNIX_PORT"'
    
    # Initialize database if not exists
    if [ ! -d "$MYSQL_DATADIR" ]; then
      echo "Initializing MariaDB..."
      mysql_install_db --no-defaults --auth-root-authentication-method=normal \
        --datadir="$MYSQL_DATADIR" --basedir="$MYSQL_BASEDIR" \
        --pid-file="$MYSQL_PID_FILE"
    fi
    
    echo "Starting MariaDB..."
    # Start MariaDB daemon
    mysqld --no-defaults --datadir="$MYSQL_DATADIR" --pid-file="$MYSQL_PID_FILE" \
      --socket="$MYSQL_UNIX_PORT" --port=3306 --bind-address=127.0.0.1 \
      --tmpdir="$TMPDIR" 2> "$MYSQL_HOME/mysql.log" &
    MYSQL_PID=$!
    
    # Wait for MariaDB to be ready
    echo "Waiting for MariaDB to start..."
    for i in {1..30}; do
      if mysqladmin ping --socket="$MYSQL_UNIX_PORT" -u root --silent 2>/dev/null; then
        echo "MariaDB started successfully!"
        break
      fi
      sleep 1
    done
    
    # Create booklore database and user if they don't exist
    mysql -u root --socket="$MYSQL_UNIX_PORT" <<EOF
CREATE DATABASE IF NOT EXISTS booklore;
CREATE USER IF NOT EXISTS 'booklore'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('booklore');
GRANT ALL PRIVILEGES ON booklore.* TO 'booklore'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Export database connection for BookLore
    export DATABASE_URL="jdbc:mariadb://localhost:3306/booklore"
    export DATABASE_USERNAME="booklore"
    export DATABASE_PASSWORD="booklore"
    
    # Cleanup function to stop MariaDB on exit
    finish() {
      echo "Shutting down MariaDB..."
      mysqladmin -u root --socket="$MYSQL_UNIX_PORT" shutdown 2>/dev/null
      kill $MYSQL_PID 2>/dev/null
      wait $MYSQL_PID 2>/dev/null
    }
    trap finish EXIT
    
    echo ""
    echo "MariaDB is running!"
    echo "Database: booklore"
    echo "User: booklore / booklore"
    echo ""
    echo "To run BookLore:"
    echo "  cd booklore-api"
    echo "  java -jar build/libs/booklore-api-0.0.1-SNAPSHOT.jar"
    echo ""
    echo "MariaDB will automatically shut down when you exit this shell."
    echo "=================================================="
  '';
}
