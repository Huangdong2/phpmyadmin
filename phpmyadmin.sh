#!/bin/bash
#################################################
# phpmyadmin installer for Centmin Mod centminmod.com
# written by George Liu (eva2000) vbtechsupport.com
#################################################
# If you have a fairly static IP address that doesn't change often
# set STATICIP='y'. Otherwise leave as STATICIP='n'
STATICIP='n'
#################################################
VER='0.0.7'
DT=`date +"%d%m%y-%H%M%S"`

UPDATEDIR='/root/tools'
BASEDIR='/usr/local/nginx/html'
DIRNAME=$(echo "${RANDOM}_mysqladmin${RANDOM}")

SALT=$(openssl rand 8 -base64)
USERPREFIX='admin'
USER=$(echo "${USERPREFIX}${SALT}")
PASS=$(openssl rand 20 -base64)
BLOWFISH=$(openssl rand 30 -base64)
CURRENTIP=$(echo $SSH_CLIENT | awk '{print $1}')
USERNAME='phpmyadmin'

SSLHNAME=$(uname -n)

VERSIONMINOR='04' # last 2 digits in Centmin Mod version i.e. 1.2.3-eva2000.04
VERSIONALLOW="1.2.3-eva2000.${VERSIONMINOR}"

#################################################
# Memory calculations for dynamic memory limit determination
TOTALMEM=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
TOTALMEMMB=`echo "scale=0;$TOTALMEM/1024" | bc`

CHECKFREEMEM=$(cat /proc/meminfo | grep MemFree)
if [[ "$CHECKFREEMEM" ]]; then
FREEMEM=$(cat /proc/meminfo | grep MemFree | awk '{print $2}')
FREEMEMMB=`echo "scale=0;$FREEMEM/1024" | bc`
else
FREEMEMMB='0'
fi

CHECKBUFFER=$(cat /proc/meminfo | grep Buffers)
if [[ "$CHECKBUFFER" ]]; then
BUFFERSMEM=$(cat /proc/meminfo | grep Buffers | awk '{print $2}')
BUFFERSMB=`echo "scale=0;$BUFFERSMEM/1024" | bc`
else
BUFFERSMB='0'
fi

CHECKCACHED=$(cat /proc/meminfo | grep ^Cached)
if [[ "$CHECKCACHED" ]]; then
CACHEDMEM=$(cat /proc/meminfo | grep ^Cached | awk '{print $2}')
CACHEDMB=`echo "scale=0;$CACHEDMEM/1024" | bc`
else
CACHEDMB='0'
fi

REALFREEMB=$(echo $FREEMEMMB+$BUFFERSMB+$CACHEDMB | bc)
REALUSEDMEM=$(echo $TOTALMEMMB-$REALFREEMB | bc)

# set php-fpm memory_limit to 4/9 th of available free memory
MEMLIMIT=$(echo $REALFREEMB / 2.25 | bc)

# echo "Total Mem: $TOTALMEMMB MB"
# echo "Real Free Mem: $REALFREEMB MB"
# echo "Mem Limit: $MEMLIMIT MB"
#################################################
CENTMINLOGDIR='/root/centminlogs'
FPMPOOLDIR='/usr/local/nginx/conf/phpfpmd'

if [ ! -d "$CENTMINLOGDIR" ]; then
mkdir -p $CENTMINLOGDIR
fi

if [ ! -d "$FPMPOOLDIR" ]; then
mkdir -p $FPMPOOLDIR
fi

# Setup Colours
black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'

boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'

Reset="tput sgr0"      #  Reset text attributes to normal
                       #+ without clearing screen.

cecho ()                     # Coloured-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
message=$1
color=$2
echo -e "$color$message" ; $Reset
return
}
#################################################
VERCHECK=$(cat /etc/centminmod-release)
MINORVER=$(cat /etc/centminmod-release | awk -F "." '{print $4}')
COMPARE=`expr $MINORVER \< $VERSIONMINOR`

if [[ "$VERCHECK" != "$VERSIONALLOW" && "$COMPARE" = '1' ]]; then
	cecho "------------------------------------------------------------------------------" $boldgreen
	cecho "  $0 script requires centmin.sh from Centmin Mod" $boldyellow
	cecho "  version: $VERSIONALLOW + recompile PHP (menu option #5)" $boldyellow
	echo ""
	cecho "  The following steps are required:" $boldyellow
	echo ""
	cecho "  1. Download and extract centmin-${VERSIONALLOW}.zip" $boldgreen
	cecho "     As per instructions at http://centminmod.com/download.html" $boldgreen
	cecho "  2. Run the updated centmin.sh script version"  $boldgreen
	echo ""
	cecho "      ./centmin.sh"  $boldwhite
	echo ""
	cecho "  3. Run menu option #5 to recompile PHP entering either the"  $boldgreen
	cecho "     same PHP version or newer PHP  5.3.x or 5.4.x version"  $boldgreen
	cecho "  4. Download latest version phpmyadmin.sh Addon script from"  $boldgreen
	cecho "     http://centminmod.com/centminmodparts/addons/phpmyadmin.sh"  $boldgreen
	cecho "     Give script appropriate permissions via command:"  $boldgreen
	echo ""
	cecho "     chmod 0700 /full/path/to/where/you/downloaded/phpmyadmin.sh"  $boldwhite
	echo ""
	cecho "  5. Add port 9418 to CSF Firewall /etc/csf/csf.conf append 9418 to existing"  $boldgreen
	cecho "     TCP_IN / TCP_OUT list of ports. Then restart CSF Firewall via command:"  $boldgreen
	echo ""
	cecho "     csf -r"  $boldwhite
	echo ""
	cecho "  6. Run phpmyadmin.sh script via commands:"  $boldgreen
	echo ""
	cecho "     cd /full/path/to/where/you/downloaded/"  $boldwhite
	cecho "     ./phpmyadmin.sh install"  $boldwhite
	#echo ""
	#cecho "  Aborting script..." $boldyellow
	cecho "------------------------------------------------------------------------------" $boldgreen
	exit
fi

#if [[ "$1" = 'resetpwd' ]]; then
#	rm -rf /usr/local/nginx/conf/phpmyadmin_check
#fi

#################################################
checkphpmyadmin() {
if [[ -f /usr/local/nginx/conf/phpmyadmin_check ]]; then
	cecho "---------------------------------------------------------------" $boldyellow
	cecho "detected phpmyadmin install that already exists" $boldgreen
	cecho "aborting..." $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow
	exit
fi
}
#################################################
memlimitmsg() {
echo ""
cecho "Dynamically set PHP memory_limit based on available system memory..." $boldyellow
echo ""
cecho "Total Mem: $TOTALMEMMB MB" $boldyellow
cecho "Real Free Mem: $REALFREEMB MB" $boldyellow
cecho "Mem Limit: $MEMLIMIT MB" $boldyellow
echo ""
}
#################################################
usercreate() {

	useradd -s /sbin/nologin -d /home/${USERNAME}/ -G nginx ${USERNAME}
	USERID=$(id ${USERNAME})
	cecho "---------------------------------------------------------------" $boldgreen
	cecho "Create User: $USERNAME" $boldyellow
	cecho "$USERID" $boldyellow
	cecho "---------------------------------------------------------------" $boldgreen
	echo ""

}

#################################################
createpassword() {
cecho "---------------------------------------------------------------" $boldyellow
cecho "Create phpmyadmin htaccess user/pass..." $boldyellow
cecho "python /usr/local/nginx/conf/htpasswd.py -c -b /usr/local/nginx/conf/htpassphpmyadmin $USER $PASS" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
python /usr/local/nginx/conf/htpasswd.py -c -b /usr/local/nginx/conf/htpassphpmyadmin $USER $PASS
}

#################################################
htpassdetails() {
echo ""
cecho "phpmyadmin htaccess login details:" $boldgreen
cecho "Username: $USER" $boldgreen
cecho "Password: $PASS" $boldgreen
cecho "Allowed IP address: ${CURRENTIP}" $boldgreen
echo ""
cecho "---------------------------------------------------------------" $boldyellow
}
#################################################
myadmininstall() {

if [[ ! -f /usr/bin/git ]]; then
	cecho "---------------------------------------------------------------" $boldyellow
	cecho "Installing git..." $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow
	cecho "yum -q -y install git --disablerepo=CentALT" $boldgreen
	yum -q -y install git --disablerepo=CentALT
	echo ""
fi

	cecho "---------------------------------------------------------------" $boldyellow
	cecho "Installing phpmyadmin from official git repository..." $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow

	cecho "This process can take some time depending on" $boldyellow
	cecho "speed of the repository and your server..." $boldyellow
	echo ""

cd $BASEDIR
git clone --depth=1 git://github.com/phpmyadmin/phpmyadmin.git $DIRNAME
cd $DIRNAME
git checkout -t origin/STABLE

cp config.sample.inc.php config.inc.php
chmod o-rw config.inc.php

replace 'a8b7c6d' "${BLOWFISH}" -- config.inc.php

sed -i 's/?>//g' config.inc.php
echo "\$cfg['ForceSSL'] = 'false';" >> config.inc.php
echo "\$cfg['ExecTimeLimit'] = '14400';" >> config.inc.php
echo "\$cfg['MemoryLimit'] = '0';" >> config.inc.php
echo "\$cfg['ShowDbStructureCreation'] = 'true';" >> config.inc.php
echo "\$cfg['ShowDbStructureLastUpdate'] = 'true';" >> config.inc.php
echo "\$cfg['ShowDbStructureLastCheck'] = 'true';" >> config.inc.php
echo "?>" >> config.inc.php

chown ${USERNAME}:nginx ${BASEDIR}/${DIRNAME}
chown -R ${USERNAME}:nginx ${BASEDIR}/${DIRNAME}
chmod g+rx ${BASEDIR}/${DIRNAME}

if [[ ! -f "/usr/local/nginx/conf/phpmyadmin.conf" ]]; then

	cecho "---------------------------------------------------------------" $boldyellow
	cecho "Setup /usr/local/nginx/conf/phpmyadmin.conf ..." $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow

createpassword 

#history -d $((HISTCMD-2))

echo ""
echo "\cp -af /usr/local/nginx/conf/php.conf /usr/local/nginx/conf/php_${DIRNAME}.conf"
\cp -af /usr/local/nginx/conf/php.conf /usr/local/nginx/conf/php_${DIRNAME}.conf

sed -i 's/fastcgi_pass   127.0.0.1:9000/#fastcgi_pass   127.0.0.1:9001/g' /usr/local/nginx/conf/php_${DIRNAME}.conf

if [[ -z "$(grep 'fastcgi_param HTTPS $server_https;' /usr/local/nginx/conf/php.conf)" ]]; then
replace '#fastcgi_param HTTPS on;' 'fastcgi_param HTTPS on;' -- /usr/local/nginx/conf/php_${DIRNAME}.conf
fi

sed -i 's/#fastcgi_pass   unix:\/tmp\/php5-fpm.sock/fastcgi_pass   unix:\/tmp\/phpfpm_myadmin.sock/g' /usr/local/nginx/conf/php_${DIRNAME}.conf

# increase php-fpm timeouts

sed -i 's/fastcgi_connect_timeout 60;/fastcgi_connect_timeout 1800;/g' /usr/local/nginx/conf/php_${DIRNAME}.conf

sed -i 's/fastcgi_send_timeout 180;/fastcgi_send_timeout 1800;/g' /usr/local/nginx/conf/php_${DIRNAME}.conf

sed -i 's/fastcgi_read_timeout 180;/fastcgi_read_timeout 1800;/g' /usr/local/nginx/conf/php_${DIRNAME}.conf

cat > "/usr/local/nginx/conf/phpmyadmin.conf" <<EOF
location ^~ /${DIRNAME}/ {
	rewrite ^/(.*) https://${SSLHNAME}/\$1 permanent;
}
EOF

sed -i "s/include \/usr\/local\/nginx\/conf\/staticfiles.conf;/include \/usr\/local\/nginx\/conf\/phpmyadmin.conf;\ninclude \/usr\/local\/nginx\/conf\/staticfiles.conf;/g" /usr/local/nginx/conf/conf.d/virtual.conf

cecho "---------------------------------------------------------------" $boldyellow

cat /usr/local/nginx/conf/conf.d/virtual.conf

cecho "---------------------------------------------------------------" $boldyellow

if [[ "$STATICIP" = 'y' && ! -z "$CURRENTIP" ]]; then

cecho "STATIC IP configuration" $boldyellow

cat > "/usr/local/nginx/conf/phpmyadmin_https.conf" <<END
location ^~ /${DIRNAME}/ {
	#try_files \$uri \$uri/ /${DIRNAME}/index.php?\$args;
	include /usr/local/nginx/conf/php_${DIRNAME}.conf;

	auth_basic      "Private Access";
	auth_basic_user_file  /usr/local/nginx/conf/htpassphpmyadmin;
	allow 127.0.0.1;
	allow ${CURRENTIP};
	deny all;
}
END

else

cecho "NON-STATIC IP configuration" $boldyellow

cat > "/usr/local/nginx/conf/phpmyadmin_https.conf" <<END
location ^~ /${DIRNAME}/ {
	#try_files \$uri \$uri/ /${DIRNAME}/index.php?\$args;
	include /usr/local/nginx/conf/php_${DIRNAME}.conf;

	auth_basic      "Private Access";
	auth_basic_user_file  /usr/local/nginx/conf/htpassphpmyadmin;
	#allow 127.0.0.1;
	#allow ${CURRENTIP};
	#deny all;
}
END

fi # STATICIP 

	cecho "---------------------------------------------------------------" $boldyellow
	cecho "cat /usr/local/nginx/conf/phpmyadmin.conf" $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow

cat /usr/local/nginx/conf/phpmyadmin.conf

	cecho "---------------------------------------------------------------" $boldyellow
	cecho "cat /usr/local/nginx/conf/phpmyadmin_https.conf" $boldgreen
	cecho "---------------------------------------------------------------" $boldyellow

cat /usr/local/nginx/conf/phpmyadmin_https.conf

	cecho "---------------------------------------------------------------" $boldyellow

# php-fpm pool setup

if [[ ! -f /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf ]]; then
	echo ""
	cecho "touch /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf" $boldgreen
	touch /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf
	touch /usr/local/nginx/conf/phpfpmd/empty.conf
	echo ""

CHECKPOOLDIR=$(grep ';include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf' /usr/local/etc/php-fpm.conf)

CHECKPOOLDIRB=$(grep 'include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf' /usr/local/etc/php-fpm.conf)

if [[ ! -z "$CHECKPOOLDIR" ]]; then
sed -i 's/;include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf/include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf/g' /usr/local/etc/php-fpm.conf
fi

#if [[ ! -z "$CHECKPOOLDIR" && -z "$CHECKPOOLDIRB" ]]; then
#sed -i 's/;include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf/include=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf/g' /usr/local/etc/php-fpm.conf
#fi

if [[ -z "$CHECKPOOLDIRB" && -z "$CHECKPOOLDIR" ]]; then
sed -i 's/process_control_timeout = 10s/process_control_timeout = 10s\ninclude=\/usr\/local\/nginx\/conf\/phpfpmd\/\*.conf/g' /usr/local/etc/php-fpm.conf
fi

CHECKPOOL=$(grep '\[phpmyadmin\]' /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf)

if [[ -z "$CHECKPOOL" ]]; then

memlimitmsg

cat >> "/usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf" <<EOF
[phpmyadmin]
user = ${USERNAME}
group = nginx

;listen = 127.0.0.1:9001
listen = /tmp/phpfpm_myadmin.sock
listen.allowed_clients = 127.0.0.1
listen.owner=${USERNAME}
listen.group=nginx

pm = ondemand
pm.max_children = 5
; Default Value: min_spare_servers + (max_spare_servers - min_spare_servers) / 2
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

pm.process_idle_timeout = 1800s;

rlimit_files = 65536
rlimit_core = 0

; The timeout for serving a single request after which the worker process will
; be killed. This option should be used when the 'max_execution_time' ini option
; does not stop script execution for some reason. A value of '0' means 'off'.
; Available units: s(econds)(default), m(inutes), h(ours), or d(ays)
; Default Value: 0
;request_terminate_timeout = 0
;request_slowlog_timeout = 0
slowlog = /var/log/php-fpm/www-slowmyadmin.log

security.limit_extensions = .php .php3 .php4 .php5

php_admin_value[open_basedir] = ${BASEDIR}/${DIRNAME}:/tmp
php_flag[display_errors] = off
php_admin_value[error_log] = /var/log/php_myadmin_error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = ${MEMLIMIT}M
php_admin_value[max_execution_time] = 1800
php_admin_value[post_max_size] = 512M
php_admin_value[upload_max_filesize] = 512M
EOF

if [[ ! -f /var/log/php_myadmin_error.log ]]; then
	touch /var/log/php_myadmin_error.log
	chown ${USERNAME}:nginx /var/log/php_myadmin_error.log
	chmod 0666 /var/log/php_myadmin_error.log
	ls -lah /var/log/php_myadmin_error.log
fi

fi # CHECKPOOL

fi # /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf

service nginx restart
service php-fpm restart

fi

}

sslvhost() {

cecho "---------------------------------------------------------------" $boldyellow
cecho "SSL Vhost Setup..." $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
echo ""

mkdir -p /usr/local/nginx/conf/ssl
cd /usr/local/nginx/conf/ssl

cecho "---------------------------------------------------------------" $boldyellow
cecho "Generating self signed SSL certificate..." $boldgreen
sleep 10
cecho "Just hit enter at each of the prompts" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
echo ""
sleep 10

openssl genrsa -out ${SSLHNAME}.key 1024
openssl req -new -key ${SSLHNAME}.key -sha256 -nodes -out ${SSLHNAME}.csr
openssl x509 -req -days 36500 -sha256 -in ${SSLHNAME}.csr -signkey ${SSLHNAME}.key -out ${SSLHNAME}.crt

cat > "/usr/local/nginx/conf/conf.d/phpmyadmin_ssl.conf"<<SSLEOF
# https SSL SPDY phpmyadmin
server {
        listen 443 ssl spdy;
            server_name ${SSLHNAME};
            root   html;

keepalive_timeout  1800;

 client_body_buffer_size 256k;
 client_body_timeout 1800s;
 client_header_buffer_size 256k;
## how long a connection has to complete sending
## it's headers for request to be processed
 client_header_timeout  60s;
 client_max_body_size 512m;
 connection_pool_size  512;
 directio  512m;
 ignore_invalid_headers on;
 large_client_header_buffers 8 256k;

        ssl_certificate      /usr/local/nginx/conf/ssl/${SSLHNAME}.crt;
        ssl_certificate_key  /usr/local/nginx/conf/ssl/${SSLHNAME}.key;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_session_cache      shared:SSL:10m;
        ssl_session_timeout  10m;
        # mozilla recommended
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!CAMELLIA;
        ssl_prefer_server_ciphers   on;
        add_header Alternate-Protocol  443:npn-spdy/3;
        add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";
        add_header X-Frame-Options SAMEORIGIN;
        spdy_headers_comp 6;
        ssl_buffer_size 1400;
        ssl_session_tickets on;

  # limit_conn limit_per_ip 16;
  # ssi  on;

        access_log              /var/log/nginx/localhost_ssl.access.log     main buffer=32k;
        error_log               /var/log/nginx/localhost_ssl.error.log      error;

# ngx_pagespeed & ngx_pagespeed handler
#include /usr/local/nginx/conf/pagespeed.conf;
#include /usr/local/nginx/conf/pagespeedhandler.conf;
#include /usr/local/nginx/conf/pagespeedstatslog.conf;

  location / {


  }
  include /usr/local/nginx/conf/phpmyadmin_https.conf;
  include /usr/local/nginx/conf/staticfiles.conf;
  include /usr/local/nginx/conf/php.conf;
  include /usr/local/nginx/conf/drop.conf;
  include /usr/local/nginx/conf/errorpage.conf;
}
SSLEOF

service nginx restart
service php-fpm restart

chmod 0666 /var/log/nginx/localhost_ssl.access.log
chmod 0666 /var/log/nginx/localhost_ssl.error.log

}

#################################################
myadminupdater() {

if [[ ! -d "$UPDATEDIR" ]]; then
	mkdir -p $UPDATEDIR
fi

if [[ ! -f "/root/tools/phpmyadmin_update.sh" ]]; then
cecho "---------------------------------------------------------------" $boldyellow
cecho "Create update script:" $boldgreen
cecho "/root/tools/phpmyadmin_update.sh" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow

cat > "/root/tools/phpmyadmin_update.sh" <<EOF
#!/bin/bash
DT=\$(date +"%d%m%y-%H%M%S")
##############################################
CENTMINLOGDIR='/root/centminlogs'

if [ ! -d "$CENTMINLOGDIR" ]; then
mkdir $CENTMINLOGDIR
fi
##############################################
starttime=\$(date +%s.%N)
{
echo "cd ${BASEDIR}/${DIRNAME}"
cd ${BASEDIR}/${DIRNAME}
echo "git pull"
git pull

chown ${USERNAME}:nginx ${BASEDIR}/${DIRNAME}
chown -R ${USERNAME}:nginx ${BASEDIR}/${DIRNAME}

} 2>&1 | tee \${CENTMINLOGDIR}/centminmod_phpmyadmin_update-\${DT}.log

endtime=\$(date +%s.%N)

INSTALLTIME=\$(echo "scale=2;\$endtime - \$starttime"|bc )
echo "" >> \${CENTMINLOGDIR}/centminmod_phpmyadmin_update-\${DT}.log 
echo "Total phpmyadmin Update Time: \$INSTALLTIME seconds" >> \${CENTMINLOGDIR}/centminmod_phpmyadmin_update-\${DT}.log
EOF

chmod 0700 /root/tools/phpmyadmin_update.sh

fi

}

#################################################
myadminremove() {

if [[ ! -d "$UPDATEDIR" ]]; then
	mkdir -p $UPDATEDIR
fi

if [[ -f "/root/tools/phpmyadmin_uninstall.sh" || ! -f "/root/tools/phpmyadmin_uninstall.sh" ]]; then
cecho "---------------------------------------------------------------" $boldyellow
cecho "Create uninstall script:" $boldgreen
cecho "/root/tools/phpmyadmin_uninstall.sh" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow

cat > "/root/tools/phpmyadmin_uninstall.sh" <<EOF
#!/bin/bash
DT=\$(date +"%d%m%y-%H%M%S")
##############################################
CENTMINLOGDIR='/root/centminlogs'

if [ ! -d "$CENTMINLOGDIR" ]; then
mkdir $CENTMINLOGDIR
fi
##############################################
starttime=\$(date +%s.%N)
{
echo "
rm -rf ${BASEDIR}/${DIRNAME}
rm -rf /root/tools/phpmyadmin_update.sh
rm -rf /usr/local/nginx/conf/conf.d/phpmyadmin_ssl.conf
rm -rf /usr/local/nginx/conf/php_${DIRNAME}.conf
rm -rf /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf
rm -rf /usr/local/nginx/conf/htpassphpmyadmin
rm -rf /usr/local/nginx/conf/phpmyadmin_https.conf
rm -rf /usr/local/nginx/conf/phpmyadmin.conf
rm -rf /usr/local/nginx/conf/phpmyadmin_check"

rm -rf ${BASEDIR}/${DIRNAME}
rm -rf /root/tools/phpmyadmin_update.sh
rm -rf /usr/local/nginx/conf/conf.d/phpmyadmin_ssl.conf
rm -rf /usr/local/nginx/conf/php_${DIRNAME}.conf
rm -rf /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf
rm -rf /usr/local/nginx/conf/htpassphpmyadmin
rm -rf /usr/local/nginx/conf/phpmyadmin_https.conf
rm -rf /usr/local/nginx/conf/phpmyadmin.conf
rm -rf /usr/local/nginx/conf/phpmyadmin_check
sed -i '/include \/usr\/local\/nginx\/conf\/phpmyadmin.conf;'/d /usr/local/nginx/conf/conf.d/virtual.conf

service nginx restart
service php-fpm restart

} 2>&1 | tee \${CENTMINLOGDIR}/centminmod_phpmyadmin_uninstall-\${DT}.log

endtime=\$(date +%s.%N)

INSTALLTIME=\$(echo "scale=2;\$endtime - \$starttime"|bc )
echo "" >> \${CENTMINLOGDIR}/centminmod_phpmyadmin_uninstall-\${DT}.log 
echo "Total phpmyadmin Update Time: \$INSTALLTIME seconds" >> \${CENTMINLOGDIR}/centminmod_phpmyadmin_uninstall-\${DT}.log
EOF

chmod 0700 /root/tools/phpmyadmin_uninstall.sh

fi

}

#################################################
myadminmsg() {

echo ""
cecho "---------------------------------------------------------------" $boldyellow
cecho "Password protected ${DIRNAME}" $boldgreen
cecho "at path ${BASEDIR}/${DIRNAME}" $boldgreen
cecho "config.inc.php at: ${BASEDIR}/${DIRNAME}/config.inc.php" $boldgreen
cecho "  WEB url: " $boldgreen
echo ""
cecho "  https://${SSLHNAME}/${DIRNAME}" $boldwhite
echo ""
cecho "Login with your MySQL root username / password" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
htpassdetails
cecho "phpmyadmin update script at: /root/tools/phpmyadmin_update.sh" $boldgreen
cecho "Add your own cron job to automatically run the update script i.e." $boldgreen
echo ""
cecho "  15 01 * * * /root/tools/phpmyadmin_update.sh" $boldwhite
echo ""
cecho "---------------------------------------------------------------" $boldyellow
cecho "phpmyadmin uninstall script at: /root/tools/phpmyadmin_uninstall.sh" $boldgreen
echo ""
cecho "  /root/tools/phpmyadmin_uninstall.sh" $boldwhite
echo ""
cecho "---------------------------------------------------------------" $boldyellow
cecho "SSL vhost: /usr/local/nginx/conf/conf.d/phpmyadmin_ssl.conf" $boldgreen
cecho "php-fpm includes: /usr/local/nginx/conf/php_${DIRNAME}.conf" $boldgreen
cecho "php-fpm pool conf: /usr/local/nginx/conf/phpfpmd/phpfpm_myadmin.conf" $boldgreen
cecho "dedicated php-fpm pool user: ${USERNAME}" $boldgreen
cecho "dedicated php-fpm pool group: nginx" $boldgreen
cecho "dedicated php error log: /var/log/php_myadmin_error.log" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
cecho "SSL vhost access log: /var/log/nginx/localhost_ssl.access.log" $boldgreen
cecho "SSL vhost error log: /var/log/nginx/localhost_ssl.error.log" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow
echo ""

echo "phpmyadmin_install='y'" > /usr/local/nginx/conf/phpmyadmin_check

}
#################################################
case "$1" in
install)
checkphpmyadmin
starttime=$(date +%s.%N)
{
	#backup csf.conf
	cp -a /etc/csf/csf.conf /etc/csf/csf.conf-backup_beforephpmyadmin_${DT}

	usercreate
	myadmininstall
	sslvhost
	myadminupdater
	myadminremove
	myadminmsg
} 2>&1 | tee ${CENTMINLOGDIR}/centminmod_phpmyadmin_install_${DT}.log

endtime=$(date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> ${CENTMINLOGDIR}/centminmod_phpmyadmin_install_${DT}.log
echo "Total phpmyadmin Install Time: $INSTALLTIME seconds" >> ${CENTMINLOGDIR}/centminmod_phpmyadmin_install_${DT}.log

cecho "---------------------------------------------------------------" $boldyellow
cecho "Total phpmyadmin Install Time: $INSTALLTIME seconds" $boldgreen
cecho "phpmyadmin install log located at:" $boldgreen
cecho "${CENTMINLOGDIR}/centminmod_phpmyadmin_install_${DT}.log" $boldgreen
cecho "---------------------------------------------------------------" $boldyellow

;;
resetpwd)
cecho "---------------------------------------------------------------" $boldyellow
createpassword
htpassdetails
;;
*)
	echo "$0 install"
	echo "$0 resetpwd"
;;
esac
exit