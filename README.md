# Obelisk Infrastructure

Docker-based development and runtime infrastructure for the [Obelisk Framework](https://github.com/Obelisk-Framework/framework).

This repository assembles FXServer, the Obelisk Lua resource, `oblsk_connector`, and one SQL backend into a repeatable local stack. Framework and connector source are mounted into the container, so code changes do not require rebuilding the image.

## What this repository provides

- An FXServer container for Linux hosts and Docker Desktop
- MariaDB and PostgreSQL Compose profiles
- Automatic FXServer bootstrap on first start
- Scripts for explicitly downloading or updating an FXServer build
- A documented `server.cfg` template
- Support for x86_64 and arm64 Docker hosts (FXServer runs through Box64 on arm64)

## Requirements

- [Git](https://git-scm.com/)
- [Docker](https://docs.docker.com/get-docker/) with Docker Compose
- Node.js 20+ and npm for `oblsk_connector`
- A FiveM server license key from [Cfx.re Keymaster](https://keymaster.fivem.net/)

The optional Linux update script also requires `curl`, `jq`, and `tar` with XZ support. You can skip the script because the container downloads the recommended FXServer build automatically when `fxserver/` is empty.

## Quick start

### 1. Clone the stack and resources

```bash
git clone https://github.com/Obelisk-Framework/infrastructure.git obelisk
cd obelisk

git clone https://github.com/Obelisk-Framework/framework.git core
git clone https://github.com/Obelisk-Framework/oblsk_connector.git oblsk_connector
npm ci --prefix oblsk_connector
```

The directory names matter: `docker-compose.yml` mounts `./core` and `./oblsk_connector` as FiveM resources.

### 2. Create the server configuration

```bash
cp server.cfg.example server.cfg
```

Open `server.cfg` and replace:

```cfg
sv_licenseKey "changeme"
```

with your license key. Do not commit `server.cfg`; it is ignored by Git because it contains local configuration and secrets.

### 3. Start with MariaDB

```bash
docker compose --profile mariadb up --build mariadb fxserver
```

MariaDB is the default backend configured by `server.cfg.example`. The first start can take several minutes while Docker builds the runtime image and FXServer downloads its recommended artifact.

Once running:

- FXServer game traffic: `30120/tcp` and `30120/udp`
- txAdmin: [http://localhost:40120](http://localhost:40120)
- MariaDB: `localhost:3306`

## PostgreSQL

To use PostgreSQL, update both database settings in `server.cfg`:

```cfg
set mysql_connection_string "postgres://obelisk:obelisk_password@postgres:5432/fivem"
set db_driver "postgres"
```

Then start the PostgreSQL profile instead of MariaDB:

```bash
docker compose --profile postgres up --build postgres fxserver
```

The profile selects which database container runs. The `db_driver` convar selects which SQL dialect the framework generates. These settings must agree.

## Managing the stack

```bash
# Follow all service logs
docker compose --profile mariadb logs -f

# Follow only FXServer
docker compose --profile mariadb logs -f fxserver

# Restart FXServer after configuration changes
docker compose --profile mariadb restart fxserver

# Stop containers without deleting database data
docker compose --profile mariadb down

# Stop containers and delete database volumes
docker compose --profile mariadb down -v
```

Replace `mariadb` with `postgres` when using the PostgreSQL profile.

> [!CAUTION]
> `docker compose down -v` permanently removes the selected database volume. Back up any data you need first.

## Updating

### Framework and connector

```bash
git -C core pull --ff-only
git -C oblsk_connector pull --ff-only
npm ci --prefix oblsk_connector
docker compose --profile mariadb restart fxserver
```

### FXServer

On Linux or in WSL, download the recommended build explicitly with:

```bash
./scripts/update-fivem-server.sh
```

You can select another Cfx.re channel:

```bash
./scripts/update-fivem-server.sh latest
```

Supported channel arguments are `recommended`, `latest`, `optional`, and `critical`. Stop FXServer before replacing an existing build, then start it again after the script finishes.

If `fxserver/` does not contain `run.sh`, the container bootstraps the configured channel automatically. Set `FXSERVER_CHANNEL` for the container if you need a channel other than `recommended`.

## Repository layout

```text
infrastructure/
├── core/                    # cloned Obelisk framework resource
├── oblsk_connector/         # cloned database connector resource
├── docker/fivem/            # FXServer image and entrypoint
├── docker/mariadb/init/     # optional MariaDB initialization files
├── scripts/                 # FXServer update helpers
├── fxserver/                # downloaded artifact; ignored by Git
├── server.cfg               # local server configuration; ignored by Git
├── server.cfg.example       # safe configuration template
└── docker-compose.yml
```

## Configuration notes

- Only start one database profile at a time.
- `mysql_connection_string` keeps its historical convar name for both supported database engines.
- `db_driver` must be `"mysql"` for MySQL/MariaDB or `"postgres"` for PostgreSQL.
- The framework resource is mounted read-only. Run CLI generators and `registry:generate` on the host inside `core/`.
- Local storage defaults to the `storage` path configured in `server.cfg`; S3-compatible storage can be enabled with the documented convars.
- Change the example database passwords before exposing this stack beyond local development.

## Troubleshooting

### `Couldn't find resource core`

Confirm that the framework was cloned to `./core`, not `./framework`, and that `core/fxmanifest.lua` exists.

### `Couldn't find resource oblsk_connector`

Confirm that the connector was cloned to `./oblsk_connector` and contains `index.js`.

### Database connection failures

Check that the active Compose profile, connection hostname, and `db_driver` all refer to the same backend. Use the Compose service names `mariadb` and `postgres` as hostnames from inside the stack.

### FXServer license errors

Verify that `server.cfg` exists and contains a valid `sv_licenseKey` issued by Cfx.re Keymaster.

### Port conflicts

Ensure ports `30120`, `40120`, and the selected database port are not already in use, or change their host-side mappings in `docker-compose.yml`.

## Documentation

See the [Obelisk documentation](https://obelisk-framework.github.io/docs/) for framework concepts, CLI usage, modules, plugins, and API reference.

## License

The Obelisk Framework is licensed under [CC BY-NC 4.0](https://github.com/Obelisk-Framework/framework/blob/main/LICENSE). Each related repository may contain additional dependency or asset licenses; review them before distribution.
