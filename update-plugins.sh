#!/bin/sh

CONFIG_FILE="/etc/git-proxy/config"
MIRROR_DIR="/var/lib/git-proxy/mirrors"
LOG_FILE="/var/log/plugin-updates.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting plugin update cycle ==="

# Create mirror directory if it doesn't exist
mkdir -p "$MIRROR_DIR"

# Function to get repo URL for a plugin
get_repo_url() {
    case "$1" in
        zsh-syntax-highlighting)
            echo "https://github.com/zsh-users/zsh-syntax-highlighting"
            ;;
        zsh-autosuggestions)
            echo "https://github.com/zsh-users/zsh-autosuggestions"
            ;;
        *)
            echo "https://github.com/ohmyzsh/ohmyzsh"
            ;;
    esac
}

# Function to update a plugin
update_plugin() {
    local plugin="$1"
    local repo_url
    repo_url=$(get_repo_url "$plugin")

    local mirror_path="$MIRROR_DIR/$plugin.git"

    if [ -d "$mirror_path" ]; then
        log "Updating: $plugin"
        cd "$mirror_path"
        if git fetch --prune 2>>"$LOG_FILE"; then
            git update-server-info
            log "Updated successfully: $plugin"
        else
            log "ERROR: Failed to update $plugin"
        fi
    else
        log "New plugin found, creating mirror: $plugin"
        if git clone --mirror "$repo_url" "$mirror_path" 2>>"$LOG_FILE"; then
            cd "$mirror_path"
            git update-server-info
            # Setup post-update hook
            cat > "hooks/post-update" << 'HOOK'
#!/bin/sh
exec git update-server-info
HOOK
            chmod +x "hooks/post-update"
            log "Mirror created: $plugin"
        else
            log "ERROR: Failed to mirror $plugin"
        fi
    fi
}

# Read plugins from config and update each one
if [ -f "$CONFIG_FILE" ]; then
    for plugin in $(cat "$CONFIG_FILE" | tr ' ' '\n'); do
        [ -z "$plugin" ] && continue
        update_plugin "$plugin"
    done
else
    log "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Update index.html
cat > "$MIRROR_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head><title>Oh-My-Zsh Plugin Proxy</title></head>
<body>
<h1>Oh-My-Zsh Plugin Proxy</h1>
<ul>
EOF

for plugin in $(cat "$CONFIG_FILE" | tr ' ' '\n'); do
    [ -z "$plugin" ] && continue
    echo "<li><a href=\"$plugin.git\">$plugin</a></li>" >> "$MIRROR_DIR/index.html"
done

cat >> "$MIRROR_DIR/index.html" << EOF
</ul>
<p>Last updated: $(date)</p>
<p>Access via: git clone git://<host>:9418/<plugin>.git</p>
</body>
</html>
EOF

log "=== Update cycle complete ==="
