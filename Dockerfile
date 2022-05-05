FROM debian:11.3

ENV APP_NAME classify

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt update \
	# && apt install -y --no-install-recommends software-properties-common \
	# && apt-add-repository non-free \
	# && apt update \
	&& apt install -y --no-install-recommends \
	python3 python3-pip \
	uwsgi uwsgi-plugins-all nginx \
	gdb telnet \
	#libmkl-dev \
	libomp-11-dev

ENV PYTHON python3

RUN ${PYTHON} -m pip install Pillow==9.1.0 remote-pdb==2.1.0

RUN ${PYTHON} -m pip install \
	--pre torch \
	--extra-index-url https://download.pytorch.org/whl/nightly/cpu

RUN ${PYTHON} -m pip install transformers==4.18.0

RUN mkdir -p /app/${APP_NAME}/${APP_NAME}

COPY uwsgi.ini /
COPY ${APP_NAME}.conf /etc/nginx/sites-enabled/default
COPY --chmod=644 out.png /tmp/out.png
COPY --chmod=755 classify.py /app/${APP_NAME}
COPY --chmod=755 entrypoint.sh /entrypoint.sh

RUN chown -R www-data /app/${APP_NAME}
RUN mkdir -p /var/log/uwsgi && chown -R www-data /var/log/uwsgi
RUN chmod 777 /root && chmod 777 /root/.cache

EXPOSE 80 443 8080

ENTRYPOINT ["/entrypoint.sh"]
