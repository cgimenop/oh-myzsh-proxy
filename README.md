# Oh-My-Zsh Plugin Proxy

A Docker-based Git proxy for oh-my-zsh plugins that automatically mirrors and updates plugin repositories.

## Features

- **Automatic mirroring**: Mirrors oh-my-zsh plugins from their upstream repositories
- **Startup sync**: On container start, reads the config file and adds any new plugins
- **Daily updates**: Cron job runs every 24 hours to update all mirrored repositories
- **Git daemon**: Exposes repositories via Git protocol (port 9418)

## Supported Plugins

- Standard oh-my-zsh plugins (git, git-prompt, colored-man, colorize, pip, python, brew, osx, etc.)
- External plugins:
  - zsh-syntax-highlighting
  - zsh-autosuggestions

## Usage

### Build and Run

```bash
# Using Docker Compose
docker-compose up -d

# Or using Docker directly
docker build -t oh-myzsh-proxy .
docker run -d -p 9418:9418 -v $(pwd)/config:/etc/git-proxy/config:ro oh-myzsh-proxy
```

### Configuration

Edit the `config` file to add or remove plugins (space-separated list):

```
git git-prompt colored-man colorize pip python brew osx zsh-syntax-highlighting zsh-autosuggestions
```

Restart the container to apply changes:

```bash
docker-compose restart
```

### Accessing Repositories

Once running, access the repositories via:

```bash
git clone git://localhost:9418/git.git
git clone git://localhost:9418/zsh-syntax-highlighting.git
```

### View Logs

```bash
# Update logs
docker exec oh-myzsh-proxy tail -f /var/log/plugin-updates.log

# Git daemon logs
docker-compose logs -f
```

### Manual Update Trigger

To trigger an immediate update (normally runs daily at 2 AM):

```bash
docker exec oh-myzsh-proxy /usr/local/bin/update-plugins.sh
```

## How It Works

1. **On startup**: The `entrypoint.sh` script reads the config file and:
   - Creates mirrors for any new plugins
   - Updates existing mirrors
   - Starts the Git daemon and cron service

2. **Daily**: A cron job runs `update-plugins.sh` at 2 AM to fetch updates for all mirrored repositories

3. **Persistence**: Mirror data is stored in a Docker volume (`plugin-mirrors`)
