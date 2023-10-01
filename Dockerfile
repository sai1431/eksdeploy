FROM registry.access.redhat.com/ubi8/ubi:8.1
RUN yum --disableplugin=subscription-manager -y module enable php:7.3 \
  && yum --disableplugin=subscription-manager -y install httpd php \
  && yum --disableplugin=subscription-manager clean all
RUN yum -y install wget php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-intl
RUN sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf \
  && sed -i 's/Listen.acl_users = apache,nginx/listen.acl_users =/' /etc/php-fpm.d/www.conf \
  && mkdir /run/php-fpm \
  && chgrp -R 0 /var/log/httpd /var/run/httpd /run/php-fpm \
  && chmod -R g=u /var/log/httpd /var/run/httpd /run/php-fpm
RUN wget https://releases.wikimedia.org/mediawiki/1.31/mediawiki-1.31.12.tar.gz
RUN tar -zxpvf mediawiki-1.31.12.tar.gz --strip-components=1 -C /var/www/html/
RUN chgrp -R 0 /var/www/html/ /var/lib/php/ && chmod -R g=u /var/www/html/ /var/lib/php/
EXPOSE 8080
USER 1001
CMD php-fpm & httpd -D FOREGROUND