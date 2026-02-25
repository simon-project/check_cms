#!/bin/bash

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
yellow_dark='\033[0;33m'
blue='\033[0;34m'
bold_cyan='\033[1;36m'
bright_green='\033[0;92m'
bright_white='\033[0;97m'
nc='\033[0m'

test_db_connection() {
    local host="$1"
    local user="$2"
    local pass="$3"
    local dbname="$4"
    local port="$5"  # необязательный аргумент

    curdate=$(date +%Y%m%d%H%M%S)

    # формируем часть команды для порта, если он указан
    local port_opt=""
    if [[ -n "$port" ]]; then
        port_opt="-P ${port}"
    fi

    if mysql -h "${host}" -u "${user}" --password="${pass}" $port_opt -e "USE ${dbname}" >/dev/null 2>&1; then
        echo -e "Test connection \t${bright_green}SUCCESS${nc}\nFor mysqldump:"
        echo -e "${blue}mysqldump --add-drop-table -h ${host} -u ${user} --password='${pass}' $port_opt ${dbname} | gzip > dump${curdate}_${dbname}.sql.gz${nc}"
        echo -e "OR mysqldump as root:"
        echo -e "${green}mysqldump --add-drop-table -R $dbname | gzip > dump${curdate}_${dbname}.sql.gz${nc}"
    else
        echo -e "${red}Test connection FAIL${nc} with user [${user}] and password [${pass}]"
        echo "mysql -h ${host} -u ${user} --password='${pass}' $port_opt -e 'USE ${dbname}'"
    fi
}

check_cms() {
    local cms_name="$1"
    local config_file="$2"
    local verify_file="$3"
    local cmds="$4"  # список команд, которые выводят значения

    if [[ -f "$config_file" && -f "$verify_file" ]]; then
        # получаем строки
        mapfile -t db_values < <(eval "$cmds")

        DB_HOST="${db_values[0]}"
        DB_USER="${db_values[1]}"
        DB_PASS="${db_values[2]}"
        DB_NAME="${db_values[3]}"
        DB_PORT="${db_values[4]}"  # port - optional

        if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASS" || -z "$DB_NAME" ]]; then
            return 1
        fi

        echo -e "\n${bold_cyan}$cms_name${nc} ${bright_white}detected${nc}"
        echo -e "Root directory:\t$(pwd)"
        echo -e "Config file:\t$(pwd)/${yellow_dark}$config_file${nc}"
        echo -e "Database settings:"
        echo -e "DB Host:\t${yellow}$DB_HOST${nc}"
        echo -e "Port:\t\t${yellow}${DB_PORT:-<default>}${nc}"  # показываем <default>, если пусто
        echo -e "Username:\t${yellow}$DB_USER${nc}"
        echo -e "Password:\t${yellow}$DB_PASS${nc}"
        echo -e "Database:\t${yellow}$DB_NAME${nc}"

        test_db_connection "$DB_HOST" "$DB_USER" "$DB_PASS" "$DB_NAME" "$DB_PORT"
        return 0
    fi

    return 1
}

search_cms() {
    local dir="$1"
    local depth="$2"
    local max_depth=5

    if (( depth > max_depth )); then
        return
    fi

    if [[ ! -d "$dir" || -L "$dir" ]]; then
        return
    fi

    # Debug
    # echo "Searching in directory: $dir at depth: $depth"

    cd "$dir" || return

    # check CMS via configs

    if check_cms "WordPress" "wp-config.php" "wp-includes/version.php" \
        "grep 'DB_HOST' wp-config.php | cut -d \"'\" -f 4; \
        grep 'DB_USER' wp-config.php | cut -d \"'\" -f 4; \
        grep 'DB_PASSWORD' wp-config.php | cut -d \"'\" -f 4; \
        grep 'DB_NAME' wp-config.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "Bitrix" "bitrix/php_interface/dbconn.php" "bitrix/.settings.php" \
        "grep 'DBHost' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2; \
        grep 'DBLogin' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2; \
        grep 'DBPassword' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2; \
        grep 'DBName' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "Bitrix (new version)" "bitrix/.settings.php" "bitrix/php_interface/dbconn.php" \
        "grep -Po \"'host'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php; \
        grep -Po \"'login'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php; \
        grep -Po \"'password'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php; \
        grep -Po \"'database'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php;"; then return; fi

    if check_cms "Laravel" ".env" "artisan" \
        "grep 'DB_HOST' .env | cut -d '=' -f 2; \
        grep 'DB_USERNAME' .env | cut -d '=' -f 2; \
        grep 'DB_PASSWORD' .env | cut -d '=' -f 2; \
        grep 'DB_DATABASE' .env | cut -d '=' -f 2;"; then return; fi

    if check_cms "Joomla" "configuration.php" "administrator/manifests/files/joomla.xml" \
        "grep '\$host' configuration.php | cut -d \"'\" -f 2; \
        grep '\$user' configuration.php | cut -d \"'\" -f 2; \
        grep '\$password' configuration.php | cut -d \"'\" -f 2; \
        grep '\$db' configuration.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "Joomla" "configuration.php" "libraries/cms/version/version.php" \
        "grep '\$host' configuration.php | cut -d \"'\" -f 2; \
        grep '\$user' configuration.php | cut -d \"'\" -f 2; \
        grep '\$password' configuration.php | cut -d \"'\" -f 2; \
        grep '\$db' configuration.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "Drupal" "sites/default/settings.php" "core/lib/Drupal.php" \
        "grep 'databases\[\"default\"\]\[\"default\"\]\[\"host\"\]' sites/default/settings.php | cut -d \"'\" -f 4; \
        grep 'databases\[\"default\"\]\[\"default\"\]\[\"username\"\]' sites/default/settings.php | cut -d \"'\" -f 4; \
        grep 'databases\[\"default\"\]\[\"default\"\]\[\"password\"\]' sites/default/settings.php | cut -d \"'\" -f 4; \
        grep 'databases\[\"default\"\]\[\"default\"\]\[\"database\"\]' sites/default/settings.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "Drupal (Old)" "sites/default/settings.php" "includes/bootstrap.inc" \
        "grep '\$db_url' sites/default/settings.php | cut -d '@' -f 2 | cut -d '/' -f 1; \
        grep '\$db_url' sites/default/settings.php | cut -d '/' -f 3 | cut -d ':' -f 1; \
        grep '\$db_url' sites/default/settings.php | cut -d '/' -f 3 | cut -d ':' -f 2 | cut -d '@' -f 1; \
        grep '\$db_url' sites/default/settings.php | cut -d '/' -f 4;"; then return; fi

    if check_cms "PrestaShop" "app/config/parameters.php" "config/settings.inc.php" \
        "grep 'database_host' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_user' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_password' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_name' app/config/parameters.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "PrestaShop" "app/config/parameters.php" "config/config.inc.php" \
        "grep 'database_host' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_user' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_password' app/config/parameters.php | cut -d \"'\" -f 4; \
        grep 'database_name' app/config/parameters.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "PrestaShop" "config/settings.inc.php" "admin/init.php" \
        "grep '_DB_SERVER_' config/settings.inc.php | cut -d '\"' -f 2; \
        grep '_DB_USER_' config/settings.inc.php | cut -d '\"' -f 2; \
        grep '_DB_PASSWD_' config/settings.inc.php | cut -d '\"' -f 2; \
        grep '_DB_NAME_' config/settings.inc.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "Magento" "app/etc/env.php" "app/Mage.php" \
        "DB_HOST=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"host\"];'; \
        DB_USER=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"username\"];'; \
        DB_PASS=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"password\"];'; \
        DB_NAME=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"dbname\"];';"; then return; fi

    if check_cms "Magento" "app/etc/local.xml" "app/Mage.php" \
        "grep -oPm1 '(?<=<host><!\[CDATA\[)[^]]+' app/etc/local.xml; \
        grep -oPm1 '(?<=<username><!\[CDATA\[)[^]]+' app/etc/local.xml; \
        grep -oPm1 '(?<=<password><!\[CDATA\[)[^]]+' app/etc/local.xml; \
        grep -oPm1 '(?<=<dbname><!\[CDATA\[)[^]]+' app/etc/local.xml;"; then return; fi

    if check_cms "MODX Revo" "config.core.php" "core/config/config.inc.php" \
        "grep 'database_server' core/config/config.inc.php | cut -d \"'\" -f 2; \
        grep 'database_user' core/config/config.inc.php | cut -d \"'\" -f 2; \    
        grep 'database_password' core/config/config.inc.php | cut -d \"'\" -f 2; \   
        grep 'dbase' core/config/config.inc.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "MODX Evo" "core/config/config.inc.php" "manager/includes/version.inc.php" \
        "grep 'database_server' core/config/config.inc.php | cut -d \"'\" -f 2; \
        grep 'database_user' core/config/config.inc.php | cut -d \"'\" -f 2; \
        grep 'database_password' core/config/config.inc.php | cut -d \"'\" -f 2; \
        grep 'dbase' core/config/config.inc.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "OpenCart" "config.php" "system/startup.php" \
        "grep 'DB_HOSTNAME' config.php | cut -d \"'\" -f 2; \
        grep 'DB_USERNAME' config.php | cut -d \"'\" -f 2; \
        grep 'DB_PASSWORD' config.php | cut -d \"'\" -f 2; \
        grep 'DB_DATABASE' config.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "Typo3" "typo3conf/LocalConfiguration.php" "index.php" \
        "grep 'host' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2; \
        grep 'user' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2; \
        grep 'password' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2; \
        grep 'dbname' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "Typo3" "typo3conf/LocalConfiguration.php" "typo3/sysext/core/ext_emconf.php" \
        "DB_HOST=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"host\"];'; \
        DB_USER=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"user\"];'; \
        DB_PASS=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"password\"];'; \
        DB_NAME=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"dbname\"];';"; then return; fi

    if check_cms "DLE" "engine/data/config.php" "index.php" \
        "grep '\"DBHOST\"' engine/data/config.php | cut -d '\"' -f 4; \
        grep '\"DBUSER\"' engine/data/config.php | cut -d '\"' -f 4; \
        grep '\"DBPASS\"' engine/data/config.php | cut -d '\"' -f 4; \
        grep '\"DBNAME\"' engine/data/config.php | cut -d '\"' -f 4;"; then return; fi

    if check_cms "Symfony" ".env" "bin/console" \
        "grep 'DATABASE_HOST' .env | cut -d '=' -f 2; \
        grep 'DATABASE_USER' .env | cut -d '=' -f 2; \
        grep 'DATABASE_PASSWORD' .env | cut -d '=' -f 2; \
        grep 'DATABASE_NAME' .env | cut -d '=' -f 2;"; then return; fi

    if check_cms "InstantCMS" "config/db.php" "includes/config.php" \
        "grep 'host' config/db.php | cut -d \"'\" -f 4; \
        grep 'user' config/db.php | cut -d \"'\" -f 4; \
        grep 'password' config/db.php | cut -d \"'\" -f 4; \
        grep 'name' config/db.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "InstantCMS (new)" "system/config/config.php" "includes/config.php" \
        "grep 'db_host' system/config/config.php | cut -d \"'\" -f 4; \
        grep 'db_user' system/config/config.php | cut -d \"'\" -f 4; \
        grep 'db_password' system/config/config.php | cut -d \"'\" -f 4; \
        grep 'db_name' system/config/config.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "LiveStreet" "config/database.php" "engine/LiveStreet.php" \
        "grep 'host' config/database.php | cut -d \"'\" -f 4; \
        grep 'user' config/database.php | cut -d \"'\" -f 4; \
        grep 'password' config/database.php | cut -d \"'\" -f 4; \
        grep 'dbname' config/database.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "LiveStreet (new)" "application/config/config.local.php" "engine/LiveStreet.php" \
        "grep 'db.params.host' application/config/config.local.php | cut -d \"'\" -f 4; \
        grep 'db.params.user' application/config/config.local.php | cut -d \"'\" -f 4; \
        grep 'db.params.pass' application/config/config.local.php | cut -d \"'\" -f 4; \
        grep 'db.params.dbname' application/config/config.local.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "Webasyst" "wa-config/db.php" "wa-config/apps.php" \
        "grep 'host' wa-config/db.php | cut -d \"'\" -f 4; \
        grep 'user' wa-config/db.php | cut -d \"'\" -f 4; \
        grep 'password' wa-config/db.php | cut -d \"'\" -f 4; \
        grep 'name' wa-config/db.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "ImageCMS" "application/config/database.php" "application/config/auth.php" \
        "grep 'hostname' application/config/database.php | cut -d '=' -f 2 | xargs; \
        grep 'username' application/config/database.php | cut -d '=' -f 2 | xargs; \
        grep 'password' application/config/database.php | cut -d '=' -f 2 | xargs; \
        grep 'database' application/config/database.php | cut -d '=' -f 2 | xargs;"; then return; fi

    if check_cms "AmiroCMS" "amiro.ini" "core/amiro.php" \
        "grep 'db_server' amiro.ini | cut -d '=' -f 2 | xargs; \
        grep 'db_user' amiro.ini | cut -d '=' -f 2 | xargs; \
        grep 'db_password' amiro.ini | cut -d '=' -f 2 | xargs; \
        grep 'db_name' amiro.ini | cut -d '=' -f 2 | xargs;"; then return; fi

    if check_cms "AmiroCMS (New)" "_local/config.ini.php" "core/amiro.php" \
        "grep 'db_server' _local/config.ini.php | cut -d '=' -f 2 | xargs; \
        grep 'db_user' _local/config.ini.php | cut -d '=' -f 2 | xargs; \
        grep 'db_password' _local/config.ini.php | cut -d '=' -f 2 | xargs; \
        grep 'db_name' _local/config.ini.php | cut -d '=' -f 2 | xargs;"; then return; fi

    if check_cms "Craft" "config/db.php" "craft" \
        "grep 'server' config/db.php | cut -d '\"' -f 4; \
        grep 'user' config/db.php | cut -d '\"' -f 4; \
        grep 'password' config/db.php | cut -d '\"' -f 4; \
        grep 'database' config/db.php | cut -d '\"' -f 4;"; then return; fi

    if check_cms "Abantecart" "system/config.php" "core/engine/version.php" \
        "grep 'DB_HOSTNAME' system/config.php | cut -d \"'\" -f 2; \
        grep 'DB_USERNAME' system/config.php | cut -d \"'\" -f 2; \
        grep 'DB_PASSWORD' system/config.php | cut -d \"'\" -f 2; \
        grep 'DB_DATABASE' system/config.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "phpBB" "config.php" "includes/constants.php" \
        "grep '\$dbhost' config.php | cut -d \"'\" -f 2; \
        grep '\$dbuser' config.php | cut -d \"'\" -f 2; \
        grep '\$dbpasswd' config.php | cut -d \"'\" -f 2; \
        grep '\$dbname' config.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "Invision Power Board" "conf_global.php" "ips_kernel/class_db.php" \
        "grep \"\$INFO\['sql_host'\]\" conf_global.php | cut -d \"'\" -f 4; \
        grep \"\$INFO\['sql_user'\]\" conf_global.php | cut -d \"'\" -f 4; \
        grep \"\$INFO\['sql_pass'\]\" conf_global.php | cut -d \"'\" -f 4; \
        grep \"\$INFO\['sql_database'\]\" conf_global.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "SMF" "Settings.php" "Sources/Subs.php" \
        "grep '\$db_server' Settings.php | cut -d \"'\" -f 2; \
        grep '\$db_user' Settings.php | cut -d \"'\" -f 2; \
        grep '\$db_passwd' Settings.php | cut -d \"'\" -f 2; \
        grep '\$db_name' Settings.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "MyBB" "inc/config.php" "inc/class_core.php" \
        "grep \"\$config\['database'\]\['hostname'\]\" inc/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['database'\]\['username'\]\" inc/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['database'\]\['password'\]\" inc/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['database'\]\['database'\]\" inc/config.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "XenForo" "src/config.php" "src/XF.php" \
        "grep 'host' src/config.php | cut -d \"'\" -f 4; \
        grep 'username' src/config.php | cut -d \"'\" -f 4; \
        grep 'password' src/config.php | cut -d \"'\" -f 4; \
        grep 'dbname' src/config.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "vBulletin" "includes/config.php" "includes/class_core.php" \
        "grep \"\$config\['Database'\]\['servername'\]\" includes/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['Database'\]\['username'\]\" includes/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['Database'\]\['password'\]\" includes/config.php | cut -d \"'\" -f 4; \
        grep \"\$config\['Database'\]\['dbname'\]\" includes/config.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "CS-Cart" "config.local.php" "app/functions/fn.database.php" \
        "grep 'db_host' config.local.php | cut -d \"'\" -f 4; \
        grep 'db_user' config.local.php | cut -d \"'\" -f 4; \
        grep 'db_password' config.local.php | cut -d \"'\" -f 4; \
        grep 'db_name' config.local.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "HostCMS" "modules/core/config/database.php" "hostcmsfiles/version.txt" \
        "grep 'host' modules/core/config/database.php | cut -d \"'\" -f 4; \
        grep 'username' modules/core/config/database.php | cut -d \"'\" -f 4; \
        grep 'password' modules/core/config/database.php | cut -d \"'\" -f 4; \
        grep 'database' modules/core/config/database.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "MediaWiki" "LocalSettings.php" "includes/DefaultSettings.php" \
        "grep -oP '\$wgDBserver\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2; \
        grep -oP '\$wgDBuser\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2; \
        grep -oP '\$wgDBpassword\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2; \
        grep -oP '\$wgDBname\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "NetCat" "netcat_vars.inc.php" "netcat/index.php" \
        "grep 'MYSQL_HOST' netcat_vars.inc.php | cut -d \"'\" -f 4; \
        grep 'MYSQL_USER' netcat_vars.inc.php | cut -d \"'\" -f 4; \
        grep 'MYSQL_PASSWORD' netcat_vars.inc.php | cut -d \"'\" -f 4; \
        grep 'MYSQL_DB_NAME' netcat_vars.inc.php | cut -d \"'\" -f 4;"; then return; fi

    if check_cms "NetCat" "vars.inc.php" "index.php" \
        "grep 'MYSQL_HOST' vars.inc.php | cut -d \"'\" -f 2; \
        grep 'MYSQL_USER' vars.inc.php | cut -d \"'\" -f 2; \
        grep 'MYSQL_PASSWORD' vars.inc.php | cut -d \"'\" -f 2; \
        grep 'MYSQL_DB_NAME' vars.inc.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "osCommerce" "includes/configure.php" "catalog/includes/version.php" \
        "grep 'DB_SERVER' includes/configure.php | cut -d \"'\" -f 2; \
        grep 'DB_SERVER_USERNAME' includes/configure.php | cut -d \"'\" -f 2; \
        grep 'DB_SERVER_PASSWORD' includes/configure.php | cut -d \"'\" -f 2; \
        grep 'DB_DATABASE' includes/configure.php | cut -d \"'\" -f 2;"; then return; fi

    if check_cms "PHPShop (may be)" "config.php" "index.php" \
        "grep '\$DB_HOST' config.php | cut -d '\"' -f 2; \
        grep '\$DB_USER' config.php | cut -d '\"' -f 2; \
        grep '\$DB_PASS' config.php | cut -d '\"' -f 2; \
        grep '\$DB_NAME' config.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "PHPShop" "phpshop/inc/config.ini" "phpshop/index.php" \
        "grep 'DB_HOST' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs; \
        grep 'DB_USER' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs; \
        grep 'DB_PASS' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs; \
        grep 'DB_NAME' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs;"; then return; fi

    if check_cms "PHPShop" "phpshop/inc/config.ini" "phpshop/index.php" \
        "grep 'host' phpshop/inc/config.ini | cut -d '\"' -f 2; \
        grep 'user_db' phpshop/inc/config.ini | cut -d '\"' -f 2; \
        grep 'pass_db' phpshop/inc/config.ini | cut -d '\"' -f 2; \
        grep 'dbase' phpshop/inc/config.ini | cut -d '\"' -f 2;"; then return; fi

    if check_cms "PunBB (may be)" "config.php" "include/punbb.php" \
        "grep 'db_host' config.php | cut -d '\"' -f 2; \
        grep 'db_user' config.php | cut -d '\"' -f 2; \
        grep 'db_pass' config.php | cut -d '\"' -f 2; \
        grep 'db_name' config.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "UMI.CMS" "config/config.php" "index.php" \
        "grep \"\$config\['host'\]\" config/config.php | cut -d '\"' -f 2; \
        grep \"\$config\['user'\]\" config/config.php | cut -d '\"' -f 2; \
        grep \"\$config\['password'\]\" config/config.php | cut -d '\"' -f 2; \
        grep \"\$config\['dbname'\]\" config/config.php | cut -d '\"' -f 2;"; then return; fi

    if check_cms "UMI.CMS" "config.ini" "index.php" \
        "grep 'core.host' config.ini | cut -d '=' -f 2 | xargs; \
        grep 'core.login' config.ini | cut -d '=' -f 2 | xargs; \
        grep 'core.password' config.ini | cut -d '=' -f 2 | xargs; \
        grep 'core.dbname' config.ini | cut -d '=' -f 2 | xargs;"; then return; fi

    if check_cms "WHMCS" "configuration.php" "includes/gatewayfunctions.php" \
        "grep '\$db_host' configuration.php | cut -d \"'\" -f 2; \
        grep '\$db_username' configuration.php | cut -d \"'\" -f 2; \
        grep '\$db_password' configuration.php | cut -d \"'\" -f 2; \
        grep '\$db_name' configuration.php | cut -d \"'\" -f 2;"; then return; fi



    # if not found CMS, go to sub
    for subdir in "$dir"/*/; do
        if [[ -d "$subdir" && ! -L "$subdir" ]]; then
            search_cms "$subdir" $((depth + 1))
        fi
    done
}

search_cms "$(pwd)" 0
