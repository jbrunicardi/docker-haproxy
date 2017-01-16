FROM debian:jessie

RUN apt-get update && apt-get install -y libssl1.0.0 libpcre3 --no-install-recommends && rm -rf /var/lib/apt/lists/*

ENV HAPROXY_MAJOR=1.7
ENV HAPROXY_VERSION=1.7.1
ENV HAPROXY_MD5=d0acaae02e444039e11892ea31dde478
ENV OPENSSL_VERSION=1.0.2j
ENV WORK_DIR=/tmp/build
ENV STATICLIBSSL=$WORK_DIR/staticlibssl

RUN mkdir -p $WORK_DIR; cd $WORK_DIR; buildDeps='gcc libc6-dev libpcre3-dev zlib1g-dev make'; otherDeps='curl ca-certificates' \
	&& apt-get update && apt-get install -y $buildDeps $otherDeps --no-install-recommends \
	&& curl -O https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz \
	&& tar -zxf openssl-$OPENSSL_VERSION.tar.gz \
	&& cd openssl-* \
	&& ./config --prefix=$STATICLIBSSL --openssldir=/etc/ssl --libdir=lib no-shared zlib-dynamic \
	&& make && make install_sw \
	&& curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
	&& echo "${HAPROXY_MD5}  haproxy.tar.gz" | md5sum -c \
	&& mkdir -p $WORK_DIR/haproxy \
	&& tar -xzf haproxy.tar.gz -C $WORK_DIR/haproxy --strip-components=1 \
	&& rm haproxy.tar.gz \
	&& make -C $WORK_DIR/haproxy \
		TARGET=linux2628 \
		USE_PCRE=1 USE_STATIC_PCRE=1 USE_PCRE_JIT=1 \
		USE_OPENSSL=1 SSL_INC=$STATICLIBSSL/include SSL_LIB=$STATICLIBSSL/lib \
		USE_ZLIB=1 ADDLIB=-ldl \
		all \
		install-bin \
	&& rm -rf /usr/src/haproxy \
	&& apt-get purge -y --auto-remove $buildDeps


COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]