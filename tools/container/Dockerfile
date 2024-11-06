FROM debian

WORKDIR /source
RUN apt-get update \
 && apt-get install --no-install-recommends -y iproute2 tcpdump \
 && apt-get autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
