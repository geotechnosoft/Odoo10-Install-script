#!/bin/bash

ODOO_USER="odoo10"
ODOO_HOME="/opt/$ODOO_USER"
ODOO_HOME_EXT="/opt/$ODOO_USER/$ODOO_USER-server"

ODOO_VERSION="10.0"

#set the superadmin password

ODOO_SUPERADMIN="superadminpassword"
ODOO_CONFIG="odoo10-server"

# Update Server

echo -e "\n- Update Terminal"
#sudo apt-get update
#sudo apt-get upgrade -y
#sudo apt-get install -y locales




sudo dpkg-reconfigure locales
sudo locale-gen C.UTF-8
sudo /usr/sbin/update-locale LANG=C.UTF-8

echo -e "\n- Set locales "
echo 'LC_ALL=C.UTF-8' >> /etc/environment

# Installing PostgreSQL Server

echo -e "\n- Installing PostgreSQL Server ===>"
sudo apt-get install postgresql -y

echo -e "\n PostgreSQL $PG_VERSION Settings  ===>"
sudo sed -i s/"#listen_addresses = 'localhost'"/"listen_addresses = '*'"/g /etc/postgresql/9.4/main/postgresql.conf

echo -e "\n Creating the ODOO PostgreSQL User =====>"
sudo su - postgres -c "createuser -s $ODOO_USER" 2> /dev/null || true

sudo service postgresql restart

# System Settings

echo -e "\n Creating ODOO10 system user ===>"
sudo adduser --system --quiet --shell=/bin/bash --home=$ODOO_HOME --gecos 'ODOO' --group $ODOO_USER

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_USER /var/log/$ODOO_USER

#--------------------------------------------------
# Install Basic Dependencies
#--------------------------------------------------
echo -e "\n Install tool packages ===>"
sudo apt-get install wget git python-pip python-imaging python-setuptools python-dev libxslt-dev libxml2-dev libldap2-dev libsasl2-dev node-less postgresql-server-dev-all -y

echo -e "\n---- Install wkhtml and place on correct place for ODOO 10 =====>"
sudo wget http://download.gna.org/wkhtmltopdf/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-trusty-amd64.deb
sudo dpkg -i wkhtmltox-0.12.2.1_linux-trusty-amd64.deb
sudo apt-get install -f -y
sudo dpkg -i wkhtmltox-0.12.2.1_linux-trusty-amd64.deb
sudo cp /usr/local/bin/wkhtmltopdf /usr/bin
sudo cp /usr/local/bin/wkhtmltoimage /usr/bin


# Install ODOO

echo -e "\n==== Download ODOO10 Server ====>"
cd $ODOO_HOME
sudo su $ODOO_USER -c "git clone --depth 1 --single-branch --branch $ODOO_VERSION https://www.github.com/odoo/odoo $ODOO_HOME_EXT/"
cd -

echo -e "\n Create custom module directory =====>"
sudo su $ODOO_USER -c "mkdir $ODOO_HOME/custom"
sudo su $ODOO_USER -c "mkdir $ODOO_HOME/custom/addons"

echo -e "\n Setting permissions on home folder =========>"
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME/*


# Install Dependencies

echo -e "\n====== Install tool packages ==========>"
sudo pip install -r $ODOO_HOME_EXT/requirements.txt

sudo easy_install pyPdf vatnumber pydot psycogreen suds ofxparse

# Configure ODOO

echo -e "* Create server config file"
sudo cp $ODOO_HOME_EXT/debian/odoo.conf /etc/$ODOO_CONFIG.conf
sudo chown $ODOO_USER:$ODOO_USER /etc/$ODOO_CONFIG.conf
sudo chmod 640 /etc/$ODOO_CONFIG.conf

echo -e "* Change server config file"
echo -e "** Remove unwanted lines"
sudo sed -i "/db_user/d" /etc/$ODOO_CONFIG.conf
sudo sed -i "/admin_passwd/d" /etc/$ODOO_CONFIG.conf
sudo sed -i "/addons_path/d" /etc/$ODOO_CONFIG.conf

echo -e "** Add correct lines"
sudo su root -c "echo 'db_user = $ODOO_USER' >> /etc/$ODOO_CONFIG.conf"
sudo su root -c "echo 'admin_passwd = $ODOO_SUPERADMIN' >> /etc/$ODOO_CONFIG.conf"
sudo su root -c "echo 'logfile = /var/log/$ODOO_USER/$ODOO_CONFIG$1.log' >> /etc/$ODOO_CONFIG.conf"
sudo su root -c "echo 'addons_path=$ODOO_HOME_EXT/addons,$ODOO_HOME/custom/addons' >> /etc/$ODOO_CONFIG.conf"

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $ODOO_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $ODOO_USER $ODOO_HOME_EXT/openerp-server --config=/etc/$ODOO_CONFIG.conf' >> $ODOO_HOME_EXT/start.sh"
sudo chmod 755 $ODOO_HOME_EXT/start.sh


# Adding ODOO as a deamon (initscript)


echo -e "* Create init file"
echo '#!/bin/sh' >> ~/$ODOO_CONFIG
echo '### BEGIN INIT INFO' >> ~/$ODOO_CONFIG
echo "# Provides: $ODOO_CONFIG" >> ~/$ODOO_CONFIG
echo '# Required-Start: $remote_fs $syslog' >> ~/$ODOO_CONFIG
echo '# Required-Stop: $remote_fs $syslog' >> ~/$ODOO_CONFIG
echo '# Should-Start: $network' >> ~/$ODOO_CONFIG
echo '# Should-Stop: $network' >> ~/$ODOO_CONFIG
echo '# Default-Start: 2 3 4 5' >> ~/$ODOO_CONFIG
echo '# Default-Stop: 0 1 6' >> ~/$ODOO_CONFIG
echo '# Short-Description: Enterprise Business Applications' >> ~/$ODOO_CONFIG
echo '# Description: ODOO Business Applications' >> ~/$ODOO_CONFIG
echo '### END INIT INFO' >> ~/$ODOO_CONFIG
echo 'PATH=/bin:/sbin:/usr/bin' >> ~/$ODOO_CONFIG
echo "DAEMON=$ODOO_HOME_EXT/odoo-bin" >> ~/$ODOO_CONFIG
echo "NAME=$ODOO_CONFIG" >> ~/$ODOO_CONFIG
echo "DESC=$ODOO_CONFIG" >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo '# Specify the user name (Default: odoo).' >> ~/$ODOO_CONFIG
echo "USER=$ODOO_USER" >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo '# Specify an alternate config file (Default: /etc/openerp-server.conf).' >> ~/$ODOO_CONFIG
echo "CONFIGFILE=\"/etc/$ODOO_CONFIG.conf\"" >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo '# pidfile' >> ~/$ODOO_CONFIG
echo 'PIDFILE=/var/run/$NAME.pid' >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo '# Additional options that are passed to the Daemon.' >> ~/$ODOO_CONFIG
echo 'DAEMON_OPTS="-c $CONFIGFILE"' >> ~/$ODOO_CONFIG
echo '[ -x $DAEMON ] || exit 0' >> ~/$ODOO_CONFIG
echo '[ -f $CONFIGFILE ] || exit 0' >> ~/$ODOO_CONFIG
echo 'checkpid() {' >> ~/$ODOO_CONFIG
echo '[ -f $PIDFILE ] || return 1' >> ~/$ODOO_CONFIG
echo 'pid=`cat $PIDFILE`' >> ~/$ODOO_CONFIG
echo '[ -d /proc/$pid ] && return 0' >> ~/$ODOO_CONFIG
echo 'return 1' >> ~/$ODOO_CONFIG
echo '}' >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo 'case "${1}" in' >> ~/$ODOO_CONFIG
echo 'start)' >> ~/$ODOO_CONFIG
echo 'echo -n "Starting ${DESC}: "' >> ~/$ODOO_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$ODOO_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$ODOO_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$ODOO_CONFIG
echo 'echo "${NAME}."' >> ~/$ODOO_CONFIG
echo ';;' >> ~/$ODOO_CONFIG
echo 'stop)' >> ~/$ODOO_CONFIG
echo 'echo -n "Stopping ${DESC}: "' >> ~/$ODOO_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$ODOO_CONFIG
echo '--oknodo' >> ~/$ODOO_CONFIG
echo 'echo "${NAME}."' >> ~/$ODOO_CONFIG
echo ';;' >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo 'restart|force-reload)' >> ~/$ODOO_CONFIG
echo 'echo -n "Restarting ${DESC}: "' >> ~/$ODOO_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$ODOO_CONFIG
echo '--oknodo' >> ~/$ODOO_CONFIG
echo 'sleep 1' >> ~/$ODOO_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$ODOO_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$ODOO_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$ODOO_CONFIG
echo 'echo "${NAME}."' >> ~/$ODOO_CONFIG
echo ';;' >> ~/$ODOO_CONFIG
echo '*)' >> ~/$ODOO_CONFIG
echo 'N=/etc/init.d/${NAME}' >> ~/$ODOO_CONFIG
echo 'echo "Usage: ${NAME} {start|stop|restart|force-reload}" >&2' >> ~/$ODOO_CONFIG
echo 'exit 1' >> ~/$ODOO_CONFIG
echo ';;' >> ~/$ODOO_CONFIG
echo '' >> ~/$ODOO_CONFIG
echo 'esac' >> ~/$ODOO_CONFIG
echo 'exit 0' >> ~/$ODOO_CONFIG

echo -e "* Security Init File"
sudo mv ~/$ODOO_CONFIG /etc/init.d/$ODOO_CONFIG
sudo chmod 755 /etc/init.d/$ODOO_CONFIG
sudo chown root: /etc/init.d/$ODOO_CONFIG

echo -e "* Start ODOO on Startup"
sudo update-rc.d $ODOO_CONFIG defaults

sudo service $ODOO_CONFIG start
echo "Done! The ODOO server can be started with: service $ODOO_CONFIG start"
