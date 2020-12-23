FROM mariadb/server:10.5

COPY ./entrypoint.sh /entrypoint.sh
COPY ./wrapper.sh /wrapper.sh
COPY ./jobber_1.4.4-1_amd64.deb /jobber_1.4.4-1_amd64.deb
COPY ./jobber /home/mysql/.jobber
RUN chown -R mysql /home/mysql
RUN chmod 640 /home/mysql/.jobber
RUN mkdir /backup && chown 999 /backup
RUN mkdir /restore && chown 999 /restore

RUN dpkg -i /jobber_1.4.4-1_amd64.deb

USER 999

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/home/mysql/.jobber" ]
