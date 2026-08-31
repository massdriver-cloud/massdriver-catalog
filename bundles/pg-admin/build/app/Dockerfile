FROM dpage/pgadmin4:8.14

# pgAdmin keeps its configuration in a SQLite file on local disk. Cloud Run's disk
# does not survive a restart, so the server list and the stored password are written
# fresh on every boot from the connection Massdriver injected.
COPY --chown=pgadmin:root start.sh /start.sh

USER root
RUN chmod +x /start.sh
USER pgadmin

ENTRYPOINT ["/start.sh"]
