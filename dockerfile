FROM nginx

RUN mkdir -p /var/www/backend
WORKDIR /var/www/backend
COPY backend .

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
