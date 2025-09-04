from nginx:alpine

copy ./index.html /usr/share/nginx/html/
COPY ./config.js.template /usr/share/nginx/html/config.js.template
COPY ./default.conf.template /etc/nginx/conf.d/default.conf.template

CMD ["/bin/sh", "-c", "envsubst '${API_URL}' < /usr/share/nginx/html/config.js.template > /usr/share/nginx/html/config.js && envsubst '${SERVER_NAME}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]

EXPOSE 80
