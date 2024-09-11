FROM ubuntu:jammy

RUN apt update && \
    apt install -y consul nginx curl bind9-dnsutils html2text && \
    apt clean all

COPY ./web-entrypoint.sh /web-entrypoint.sh

ENTRYPOINT ["/web-entrypoint.sh"]
