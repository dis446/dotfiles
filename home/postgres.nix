{ lib, pkgs, ... }:
# PostgreSQL 18 as a Home Manager *user* service. Replaces the dnf
# `postgresql-server` + `postgresql-contrib` pair that fedora/dbs/install_postgres.sh
# used to install (that script is deleted — see AGENTS.md, "Databases").
#
# Why a user service: this repo is standalone Home Manager on non-NixOS, where
# Nix cannot own system units. So postgres runs under the user manager as the
# login user, with its cluster in $HOME — no root at any point except the
# one-time `loginctl enable-linger` that keeps it alive across logout and reboot.
#
# The major version is pinned deliberately. A cluster's data directory is only
# readable by the same major, so following the moving `pkgs.postgresql` default
# would break the cluster the first time nixpkgs bumps it to 19. Bump this attr
# and run pg_upgrade on purpose instead.
#
# Auth is trust and listening is loopback-only. That is not a new exposure: the
# data directory belongs to the login user, so any local process that could open
# a connection could already read those files directly. If the cluster ever holds
# data that matters more than that, set a password and switch the two `--auth-*`
# flags to scram-sha-256.
let
  pg = pkgs.postgresql_18;
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  # psql, pg_dump/pg_restore, pg_isready, initdb — the client set the dnf
  # packages used to provide. 79 contrib extensions ship in the same output, so
  # there is no separate contrib package to install.
  home.packages = [ pg ];

  systemd.user.services.postgresql = {
    Unit = {
      Description = "PostgreSQL ${pg.version} (nix, user service)";
      After = [ "default.target" ];
    };
    Service = {
      # nixpkgs postgres is configured --with-systemd (verified: links
      # libsystemd), so it sends its own READY=1 and needs no readiness polling
      # in ExecStartPost.
      Type = "notify";
      Environment = [ "PGDATA=%h/.local/share/postgres/data" ];
      # Create the cluster on first start, then no-op forever. Doing this here
      # rather than in an activation script keeps `home-manager switch` free of
      # initdb work and makes a wiped datadir self-heal on the next start.
      ExecStartPre = pkgs.writeShellScript "postgres-initdb" ''
        set -eu
        if [ -f "$PGDATA/PG_VERSION" ]; then exit 0; fi
        mkdir -p "$PGDATA"
        chmod 700 "$PGDATA"
        exec ${pg}/bin/initdb -D "$PGDATA" \
          --encoding=UTF8 --locale=C.UTF-8 -U postgres \
          --auth-local=trust --auth-host=trust
      '';
      # -k is the unix socket dir; systemd creates/cleans %t/postgres around the
      # service, so no stale socket is ever left in /tmp. Port 5432 is kept
      # because every dev app and DBEE profile already expects it.
      ExecStart = "${pg}/bin/postgres -D $PGDATA -p 5432 -c listen_addresses=localhost -k %t/postgres";
      RuntimeDirectory = "postgres";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
