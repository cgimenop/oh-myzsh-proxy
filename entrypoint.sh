#!/bin/sh

set -e

CONFIG_FILE="/etc/git-proxy/config"
MIRROR_DIR="/var/lib/git-proxy/mirrors"

echo "=== Oh-My-Zsh Plugin Proxy ==="
echo "Reading config from $CONFIG_FILE"

# Create mirror directory
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
            # Standard oh-my-zsh plugins
            echo "https://github.com/ohmyzsh/ohmyzsh"
            ;;
    esac
}

# Function to sync a plugin
sync_plugin() {
    local plugin="$1"
    local repo_url
    repo_url=$(get_repo_url "$plugin")

    if [ -z "$repo_url" ]; then
        echo "Unknown plugin: $plugin"
        return 1
    fi

    local mirror_path="$MIRROR_DIR/$plugin.git"

    if [ -d "$mirror_path" ]; then
        echo "Updating mirror: $plugin"
        cd "$mirror_path"

        # For oh-my-zsh, we need to fetch and then filter for the plugin
        if [ "$plugin" = "zsh-syntax-highlighting" ] || [ "$plugin" = "zsh-autosuggestions" ]; then
            git fetch --prune
            git update-server-info
        else
            git fetch --prune
            # Update server info for http access
            git update-server-info
        fi
    else
        echo "Creating mirror: $plugin"
        if [ "$plugin" = "zsh-syntax-highlighting" ] || [ "$plugin" = "zsh-autosuggestions" ]; then
            git clone --mirror "$repo_url" "$mirror_path"
        else
            # For oh-my-zsh, clone full repo but we'll expose via sparse checkout pattern
            git clone --mirror "$repo_url" "$mirror_path"
        fi
        cd "$mirror_path"
        git update-server-info
    fi

    # Set up post-update hook for git-daemon
    cat > "hooks/post-update" << 'HOOK'
#!/bin/sh
exec git update-server-info
HOOK
    chmod +x "hooks/post-update"

    echo "Mirror ready: $plugin"
}

# Read plugins from config and sync each one
if [ -f "$CONFIG_FILE" ]; then
    echo "Syncing plugins..."
    for plugin in $(cat "$CONFIG_FILE" | tr ' ' '\n'); do
        # Skip empty lines
        [ -z "$plugin" ] && continue
        sync_plugin "$plugin"
    done
else
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Create an index page
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
<p>Access via: git clone git://<host>:9418/<plugin>.git</p>
</body>
</html>
EOF

echo ""
echo "=== Starting services ==="

# Start crond for periodic updates
crond

# Start git-daemon
echo "Starting git-daemon on port 9418..."
exec git daemon \
    --reuseaddr \
    --base-path="$MIRROR_DIR" \
    --export-all \
    --enable=receive-pack \
    --verbose \
    --port=9418
