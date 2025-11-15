{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.booklore;
  booklore = pkgs.callPackage ./package.nix {};
in {
  options.services.booklore = {
    enable = mkEnableOption "BookLore service";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for the BookLore backend";
    };

    hostName = mkOption {
      type = types.str;
      default = "localhost";
      description = "Hostname for nginx virtual host";
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "booklore";
        description = "Database name";
      };

      user = mkOption {
        type = types.str;
        default = "booklore";
        description = "Database user";
      };

      password = mkOption {
        type = types.str;
        default = "booklore";
        description = "Database password (consider using passwordFile for production)";
      };
    };
  };

  config = mkIf cfg.enable {
    # MariaDB setup
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [{
        name = cfg.database.user;
        ensurePermissions = {
          "${cfg.database.name}.*" = "ALL PRIVILEGES";
        };
      }];
    };

    # Nginx setup
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.hostName} = {
        locations."/" = {
          root = "${booklore}/share/booklore/static";
          tryFiles = "$uri $uri/ /index.html";
        };
        
        locations."/api" = {
          proxyPass = "http://localhost:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

    # BookLore backend systemd service
    systemd.services.booklore = {
      description = "BookLore Backend Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "mysql.service" ];
      requires = [ "mysql.service" ];

      environment = {
        DATABASE_URL = "jdbc:mariadb://localhost:3306/${cfg.database.name}";
        DATABASE_USERNAME = cfg.database.user;
        DATABASE_PASSWORD = cfg.database.password;
      };

      serviceConfig = {
        Type = "simple";
        User = "booklore";
        Group = "booklore";
        ExecStart = ''
          ${booklore}/bin/booklore \
            --server.port=${toString cfg.port} \
            --spring.datasource.url=jdbc:mariadb://localhost:3306/${cfg.database.name} \
            --spring.datasource.username=${cfg.database.user} \
            --spring.datasource.password=${cfg.database.password}
        '';
        Restart = "on-failure";
        RestartSec = "10s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Create user and group
    users.users.booklore = {
      isSystemUser = true;
      group = "booklore";
      description = "BookLore service user";
    };

    users.groups.booklore = {};

    # Open firewall for nginx if needed
    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
