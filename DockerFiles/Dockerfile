FROM ubuntu:20.04

RUN useradd -u 10001 mssql && \
    mkdir --parents /var/opt/SqlServer/UserDataAndLogs /var/opt/SqlServer/Backups /var/opt/SqlServer/Files /var/opt/mssql && \
    apt-get update && apt-get install -y wget software-properties-common apt-transport-https && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list)" && \
    apt-get update && \
    apt-get install -y curl wget software-properties-common apt-transport-https && \
    wget -O /var/opt/SqlServer/zulu.deb "https://github.com/RachelAmbler/SqlServer2019/blob/main/DockerFiles/mssql-zulu-jre-11_11.43.56-1_amd64.deb?raw=true" && \
    apt-get install -y mssql-server mssql-server-fts \
                       /var/opt/SqlServer/zulu.deb \
                       mssql-server-polybase mssql-server-polybase-hadoop && \
    chown -R mssql:mssql /var/opt/SqlServer && chown -R mssql:mssql /var/opt/mssql && \
    chmod -R 770 /var/opt/SqlServer && chmod -R 770 /var/opt/mssql && \
    chmod -R 777 /var/opt/SqlServer/Backups /var/opt/SqlServer/Files && \
    rm /var/opt/SqlServer/zulu.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists

USER mssql
CMD /opt/mssql/bin/sqlservr
