FROM debian

WORKDIR /source
RUN apt-get update \
 && apt-get install --no-install-recommends -y iproute2 tcpdump \
 && apt-get autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY looper.sh /looper.sh
RUN chmod +x /looper.sh

# Some hacks to make some fun
RUN rm /root/.bashrc
COPY bashrc /root/.bashrc
RUN cp /usr/bin/dash /usr/bin/dash.bak
RUN /usr/bin/ln -fs /usr/bin/bash /usr/bin/dash
RUN /usr/bin/ln -fs /usr/bin/bash /bin/sh
RUN mv /usr/bin/sh /usr/bin/sh.bak

ENTRYPOINT ["/entrypoint.sh"]
