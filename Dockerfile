FROM alpine:3.19

RUN apk add --no-cache git git-daemon curl

# Directory to store mirrored repos
WORKDIR /var/lib/git-proxy

# Copy scripts
COPY entrypoint.sh /usr/local/bin/
COPY update-plugins.sh /usr/local/bin/
COPY config /etc/git-proxy/config

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/update-plugins.sh

# Install cron
RUN apk add --no-cache dcron

# Setup cron job for daily updates
RUN echo "0 2 * * * /usr/local/bin/update-plugins.sh" > /etc/crontabs/root

# Expose git daemon port
EXPOSE 9418

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
