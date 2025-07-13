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

    #MYSQL_PWD=$(printf '%q' "$pass")
    curdate=$(date +%Y%m%d%H%M%S)
    if mysql -h "${host}" -u "${user}" --password="${pass}" -e "USE ${dbname}" >/dev/null 2>&1; then
        echo -e "Test connection \t${bright_green}SUCCESS${nc}\nFor mysqldump:"
        echo -e "${blue}mysqldump --add-drop-table -h ${host} -u ${user} --password='${pass}' ${dbname} | gzip > dump${curdate}_${dbname}.sql.gz${nc}"
        echo -e "OR mysqldump as root:"
        echo -e "${green}mysqldump --add-drop-table -R ${dbname} | gzip > dump${curdate}_${dbname}.sql.gz${nc}"
    else
        echo -e "${red}Test connection FAIL${nc} with user [${user}] and password [${pass}]"
    echo "mysql -h ${host} -u ${user} --password='${pass}' -e 'USE ${dbname}'"
    fi
}

check_cms() {
    local cms_name="$1"
    local config_file="$2"
    local verify_file="$3"
    local db_settings_function="$4"

    if [[ -f "$config_file" && -f "$verify_file" ]]; then

        # Get DB settings
        eval "$db_settings_function"
        if [[ "${DB_HOST}" == "1" || "${DB_USER}" == "" || "${DB_PASS}" == "" || "${DB_NAME}" == "" ]]; then
            return 1
        fi

        echo -e "\n${bold_cyan}$cms_name${nc} ${bright_white}detected${nc}"
        echo -e "Root directory:\t$(pwd)"
        echo -e "Config file: \t$(pwd)/${yellow_dark}$config_file${nc}"
        echo -e "Database settings:"
        echo -e "DB Host: \t${yellow}$DB_HOST${nc}"
        echo -e "Username: \t${yellow}$DB_USER${nc}"
        echo -e "Password: \t${yellow}$DB_PASS${nc}"
        echo -e "Database: \t${yellow}$DB_NAME${nc}"

        test_db_connection "$DB_HOST" "$DB_USER" "$DB_PASS" "$DB_NAME"
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
    "DB_HOST=\$(grep 'DB_HOST' wp-config.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'DB_USER' wp-config.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'DB_PASSWORD' wp-config.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'DB_NAME' wp-config.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "Bitrix" "bitrix/php_interface/dbconn.php" "bitrix/.settings.php" \
    "DB_HOST=\$(grep 'DBHost' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep 'DBLogin' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep 'DBPassword' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep 'DBName' bitrix/php_interface/dbconn.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "Bitrix (new version)" "bitrix/.settings.php" "bitrix/php_interface/dbconn.php" \
    "DB_HOST=\$(grep -Po \"'host'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php); \
    DB_USER=\$(grep -Po \"'login'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php); \
    DB_PASS=\$(grep -Po \"'password'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php); \
    DB_NAME=\$(grep -Po \"'database'\\s*=>\\s*'\\K[^']+\" bitrix/.settings.php)"; then return; fi

if check_cms "Laravel" ".env" "artisan" \
    "DB_HOST=\$(grep 'DB_HOST' .env | cut -d '=' -f 2); \
    DB_USER=\$(grep 'DB_USERNAME' .env | cut -d '=' -f 2); \
    DB_PASS=\$(grep 'DB_PASSWORD' .env | cut -d '=' -f 2); \
    DB_NAME=\$(grep 'DB_DATABASE' .env | cut -d '=' -f 2)"; then return; fi

if check_cms "Joomla" "configuration.php" "administrator/manifests/files/joomla.xml" \
    "DB_HOST=\$(grep '\$host' configuration.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep '\$user' configuration.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep '\$password' configuration.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep '\$db' configuration.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "Joomla" "configuration.php" "libraries/cms/version/version.php" \
    "DB_HOST=\$(grep '\$host' configuration.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep '\$user' configuration.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep '\$password' configuration.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep '\$db' configuration.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "Drupal" "sites/default/settings.php" "core/lib/Drupal.php" \
    "DB_HOST=\$(grep 'databases\[\"default\"\]\[\"default\"\]\[\"host\"\]' sites/default/settings.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'databases\[\"default\"\]\[\"default\"\]\[\"username\"\]' sites/default/settings.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'databases\[\"default\"\]\[\"default\"\]\[\"password\"\]' sites/default/settings.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'databases\[\"default\"\]\[\"default\"\]\[\"database\"\]' sites/default/settings.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "Drupal (Old)" "sites/default/settings.php" "includes/bootstrap.inc" \
    "DB_HOST=\$(grep '\$db_url' sites/default/settings.php | cut -d '@' -f 2 | cut -d '/' -f 1); \
    DB_USER=\$(grep '\$db_url' sites/default/settings.php | cut -d '/' -f 3 | cut -d ':' -f 1); \
    DB_PASS=\$(grep '\$db_url' sites/default/settings.php | cut -d '/' -f 3 | cut -d ':' -f 2 | cut -d '@' -f 1); \
    DB_NAME=\$(grep '\$db_url' sites/default/settings.php | cut -d '/' -f 4)"; then return; fi

if check_cms "PrestaShop" "app/config/parameters.php" "config/settings.inc.php" \
    "DB_HOST=\$(grep 'database_host' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'database_user' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'database_password' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'database_name' app/config/parameters.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "PrestaShop" "app/config/parameters.php" "config/config.inc.php" \
    "DB_HOST=\$(grep 'database_host' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'database_user' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'database_password' app/config/parameters.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'database_name' app/config/parameters.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "PrestaShop" "config/settings.inc.php" "admin/init.php" \
    "DB_HOST=\$(grep '_DB_SERVER_' config/settings.inc.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep '_DB_USER_' config/settings.inc.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep '_DB_PASSWD_' config/settings.inc.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep '_DB_NAME_' config/settings.inc.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "Magento" "app/etc/env.php" "app/Mage.php" \
    "DB_HOST=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"host\"];'); \
    DB_USER=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"username\"];'); \
    DB_PASS=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"password\"];'); \
    DB_NAME=\$(php -r 'include \"app/etc/env.php\"; echo \$config[\"db\"][\"connection\"][\"default\"][\"dbname\"];')"; then return; fi

if check_cms "Magento" "app/etc/local.xml" "app/Mage.php" \
    "DB_HOST=\$(grep -oPm1 '(?<=<host><!\[CDATA\[)[^]]+' app/etc/local.xml); \
    DB_USER=\$(grep -oPm1 '(?<=<username><!\[CDATA\[)[^]]+' app/etc/local.xml); \
    DB_PASS=\$(grep -oPm1 '(?<=<password><!\[CDATA\[)[^]]+' app/etc/local.xml); \
    DB_NAME=\$(grep -oPm1 '(?<=<dbname><!\[CDATA\[)[^]]+' app/etc/local.xml)"; then return; fi

if check_cms "MODX Revo" "config.core.php" "core/config/config.inc.php" \
    "DB_HOST=\$(grep 'database_server' core/config/config.inc.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'database_user' core/config/config.inc.php | cut -d \"'\" -f 2); \    
    DB_PASS=\$(grep 'database_password' core/config/config.inc.php | cut -d \"'\" -f 2); \   
    DB_NAME=\$(grep 'dbase' core/config/config.inc.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "MODX Evo" "core/config/config.inc.php" "manager/includes/version.inc.php" \
    "DB_HOST=\$(grep 'database_server' core/config/config.inc.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'database_user' core/config/config.inc.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep 'database_password' core/config/config.inc.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep 'dbase' core/config/config.inc.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "OpenCart" "config.php" "system/startup.php" \
    "DB_HOST=\$(grep 'DB_HOSTNAME' config.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'DB_USERNAME' config.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep 'DB_PASSWORD' config.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep 'DB_DATABASE' config.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "Typo3" "typo3conf/LocalConfiguration.php" "index.php" \
    "DB_HOST=\$(grep 'host' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep 'user' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep 'password' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep 'dbname' typo3conf/LocalConfiguration.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "Typo3" "typo3conf/LocalConfiguration.php" "typo3/sysext/core/ext_emconf.php" \
    "DB_HOST=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"host\"];'); \
    DB_USER=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"user\"];'); \
    DB_PASS=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"password\"];'); \
    DB_NAME=\$(php -r 'include \"typo3conf/LocalConfiguration.php\"; echo \$GLOBALS[\"TYPO3_CONF_VARS\"][\"DB\"][\"Connections\"][\"Default\"][\"dbname\"];')"; then return; fi

if check_cms "DLE" "engine/data/config.php" "index.php" \
    "DB_HOST=\$(grep '\"DBHOST\"' engine/data/config.php | cut -d '\"' -f 4); \
    DB_USER=\$(grep '\"DBUSER\"' engine/data/config.php | cut -d '\"' -f 4); \
    DB_PASS=\$(grep '\"DBPASS\"' engine/data/config.php | cut -d '\"' -f 4); \
    DB_NAME=\$(grep '\"DBNAME\"' engine/data/config.php | cut -d '\"' -f 4)"; then return; fi

if check_cms "Symfony" ".env" "bin/console" \
    "DB_HOST=\$(grep 'DATABASE_HOST' .env | cut -d '=' -f 2); \
    DB_USER=\$(grep 'DATABASE_USER' .env | cut -d '=' -f 2); \
    DB_PASS=\$(grep 'DATABASE_PASSWORD' .env | cut -d '=' -f 2); \
    DB_NAME=\$(grep 'DATABASE_NAME' .env | cut -d '=' -f 2)"; then return; fi

if check_cms "InstantCMS" "config/db.php" "includes/config.php" \
    "DB_HOST=\$(grep 'host' config/db.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'user' config/db.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'password' config/db.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'name' config/db.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "InstantCMS (new)" "system/config/config.php" "includes/config.php" \
    "DB_HOST=\$(grep 'db_host' system/config/config.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'db_user' system/config/config.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'db_password' system/config/config.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'db_name' system/config/config.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "LiveStreet" "config/database.php" "engine/LiveStreet.php" \
    "DB_HOST=\$(grep 'host' config/database.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'user' config/database.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'password' config/database.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'dbname' config/database.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "LiveStreet (new)" "application/config/config.local.php" "engine/LiveStreet.php" \
    "DB_HOST=\$(grep 'db.params.host' application/config/config.local.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'db.params.user' application/config/config.local.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'db.params.pass' application/config/config.local.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'db.params.dbname' application/config/config.local.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "Webasyst" "wa-config/db.php" "wa-config/apps.php" \
    "DB_HOST=\$(grep 'host' wa-config/db.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'user' wa-config/db.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'password' wa-config/db.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'name' wa-config/db.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "ImageCMS" "application/config/database.php" "application/config/auth.php" \
    "DB_HOST=\$(grep 'hostname' application/config/database.php | cut -d '=' -f 2 | xargs); \
    DB_USER=\$(grep 'username' application/config/database.php | cut -d '=' -f 2 | xargs); \
    DB_PASS=\$(grep 'password' application/config/database.php | cut -d '=' -f 2 | xargs); \
    DB_NAME=\$(grep 'database' application/config/database.php | cut -d '=' -f 2 | xargs)"; then return; fi

if check_cms "AmiroCMS" "amiro.ini" "core/amiro.php" \
    "DB_HOST=\$(grep 'db_server' amiro.ini | cut -d '=' -f 2 | xargs); \
    DB_USER=\$(grep 'db_user' amiro.ini | cut -d '=' -f 2 | xargs); \
    DB_PASS=\$(grep 'db_password' amiro.ini | cut -d '=' -f 2 | xargs); \
    DB_NAME=\$(grep 'db_name' amiro.ini | cut -d '=' -f 2 | xargs)"; then return; fi

if check_cms "AmiroCMS (New)" "_local/config.ini.php" "core/amiro.php" \
    "DB_HOST=\$(grep 'db_server' _local/config.ini.php | cut -d '=' -f 2 | xargs); \
    DB_USER=\$(grep 'db_user' _local/config.ini.php | cut -d '=' -f 2 | xargs); \
    DB_PASS=\$(grep 'db_password' _local/config.ini.php | cut -d '=' -f 2 | xargs); \
    DB_NAME=\$(grep 'db_name' _local/config.ini.php | cut -d '=' -f 2 | xargs)"; then return; fi

if check_cms "Craft" "config/db.php" "craft" \
    "DB_HOST=\$(grep 'server' config/db.php | cut -d '\"' -f 4); \
    DB_USER=\$(grep 'user' config/db.php | cut -d '\"' -f 4); \
    DB_PASS=\$(grep 'password' config/db.php | cut -d '\"' -f 4); \
    DB_NAME=\$(grep 'database' config/db.php | cut -d '\"' -f 4)"; then return; fi

if check_cms "Abantecart" "system/config.php" "core/engine/version.php" \
    "DB_HOST=\$(grep 'DB_HOSTNAME' system/config.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'DB_USERNAME' system/config.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep 'DB_PASSWORD' system/config.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep 'DB_DATABASE' system/config.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "phpBB" "config.php" "includes/constants.php" \
    "DB_HOST=\$(grep '\$dbhost' config.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep '\$dbuser' config.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep '\$dbpasswd' config.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep '\$dbname' config.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "Invision Power Board" "conf_global.php" "ips_kernel/class_db.php" \
    "DB_HOST=\$(grep '\$INFO\[\'sql_host\']' conf_global.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep '\$INFO\[\'sql_user\']' conf_global.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep '\$INFO\[\'sql_pass\']' conf_global.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep '\$INFO\[\'sql_database\']' conf_global.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "SMF" "Settings.php" "Sources/Subs.php" \
    "DB_HOST=\$(grep '\$db_server' Settings.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep '\$db_user' Settings.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep '\$db_passwd' Settings.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep '\$db_name' Settings.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "MyBB" "inc/config.php" "inc/class_core.php" \
    "DB_HOST=\$(grep '\$config\[\'database\'][\'hostname\']' inc/config.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep '\$config\[\'database\'][\'username\']' inc/config.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep '\$config\[\'database\'][\'password\']' inc/config.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep '\$config\[\'database\'][\'database\']' inc/config.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "XenForo" "src/config.php" "src/XF.php" \
    "DB_HOST=\$(grep 'host' src/config.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'username' src/config.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'password' src/config.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'dbname' src/config.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "vBulletin" "includes/config.php" "includes/class_core.php" \
    "DB_HOST=\$(grep '\$config\[\'Database\'][\'servername\']' includes/config.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep '\$config\[\'Database\'][\'username\']' includes/config.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep '\$config\[\'Database\'][\'password\']' includes/config.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep '\$config\[\'Database\'][\'dbname\']' includes/config.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "CS-Cart" "config.local.php" "app/functions/fn.database.php" \
    "DB_HOST=\$(grep 'db_host' config.local.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'db_user' config.local.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'db_password' config.local.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'db_name' config.local.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "HostCMS" "modules/core/config/database.php" "hostcmsfiles/version.txt" \
    "DB_HOST=\$(grep 'host' modules/core/config/database.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'username' modules/core/config/database.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'password' modules/core/config/database.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'database' modules/core/config/database.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "MediaWiki" "LocalSettings.php" "includes/DefaultSettings.php" \
    "DB_HOST=\$(grep -oP '\$wgDBserver\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep -oP '\$wgDBuser\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep -oP '\$wgDBpassword\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep -oP '\$wgDBname\s*=\s*\"([^\"]+)\";' LocalSettings.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "NetCat" "netcat_vars.inc.php" "netcat/index.php" \
    "DB_HOST=\$(grep 'MYSQL_HOST' netcat_vars.inc.php | cut -d \"'\" -f 4); \
    DB_USER=\$(grep 'MYSQL_USER' netcat_vars.inc.php | cut -d \"'\" -f 4); \
    DB_PASS=\$(grep 'MYSQL_PASSWORD' netcat_vars.inc.php | cut -d \"'\" -f 4); \
    DB_NAME=\$(grep 'MYSQL_DB_NAME' netcat_vars.inc.php | cut -d \"'\" -f 4)"; then return; fi

if check_cms "NetCat" "vars.inc.php" "index.php" \
    "DB_HOST=\$(grep 'MYSQL_HOST' vars.inc.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'MYSQL_USER' vars.inc.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep 'MYSQL_PASSWORD' vars.inc.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep 'MYSQL_DB_NAME' vars.inc.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "osCommerce" "includes/configure.php" "catalog/includes/version.php" \
    "DB_HOST=\$(grep 'DB_SERVER' includes/configure.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep 'DB_SERVER_USERNAME' includes/configure.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep 'DB_SERVER_PASSWORD' includes/configure.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep 'DB_DATABASE' includes/configure.php | cut -d \"'\" -f 2)"; then return; fi

if check_cms "PHPShop (may be)" "config.php" "index.php" \
    "DB_HOST=\$(grep '\$DB_HOST' config.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep '\$DB_USER' config.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep '\$DB_PASS' config.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep '\$DB_NAME' config.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "PHPShop" "phpshop/inc/config.ini" "phpshop/index.php" \
    "DB_HOST=\$(grep 'DB_HOST' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs); \
    DB_USER=\$(grep 'DB_USER' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs); \
    DB_PASS=\$(grep 'DB_PASS' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs); \
    DB_NAME=\$(grep 'DB_NAME' phpshop/inc/config.ini | cut -d '=' -f 2 | xargs)"; then return; fi

if check_cms "PHPShop" "phpshop/inc/config.ini" "phpshop/index.php" \
    "DB_HOST=\$(grep 'host' phpshop/inc/config.ini | cut -d '\"' -f 2); \
    DB_USER=\$(grep 'user_db' phpshop/inc/config.ini | cut -d '\"' -f 2); \
    DB_PASS=\$(grep 'pass_db' phpshop/inc/config.ini | cut -d '\"' -f 2); \
    DB_NAME=\$(grep 'dbase' phpshop/inc/config.ini | cut -d '\"' -f 2)"; then return; fi

if check_cms "PunBB (may be)" "config.php" "include/punbb.php" \
    "DB_HOST=\$(grep 'db_host' config.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep 'db_user' config.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep 'db_pass' config.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep 'db_name' config.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "UMI.CMS" "config/config.php" "index.php" \
    "DB_HOST=\$(grep '\$config[\'host\']' config/config.php | cut -d '\"' -f 2); \
    DB_USER=\$(grep '\$config[\'user\']' config/config.php | cut -d '\"' -f 2); \
    DB_PASS=\$(grep '\$config[\'password\']' config/config.php | cut -d '\"' -f 2); \
    DB_NAME=\$(grep '\$config[\'dbname\']' config/config.php | cut -d '\"' -f 2)"; then return; fi

if check_cms "UMI.CMS" "config.ini" "index.php" \
    "DB_HOST=\$(grep 'core.host' config.ini | cut -d '=' -f 2 | xargs); \
    DB_USER=\$(grep 'core.login' config.ini | cut -d '=' -f 2 | xargs); \
    DB_PASS=\$(grep 'core.password' config.ini | cut -d '=' -f 2 | xargs); \
    DB_NAME=\$(grep 'core.dbname' config.ini | cut -d '=' -f 2 | xargs)"; then return; fi

if check_cms "WHMCS" "configuration.php" "includes/gatewayfunctions.php" \
    "DB_HOST=\$(grep '\$db_host' configuration.php | cut -d \"'\" -f 2); \
    DB_USER=\$(grep '\$db_username' configuration.php | cut -d \"'\" -f 2); \
    DB_PASS=\$(grep '\$db_password' configuration.php | cut -d \"'\" -f 2); \
    DB_NAME=\$(grep '\$db_name' configuration.php | cut -d \"'\" -f 2)"; then return; fi

    # if not found CMS, go to sub
    for subdir in "$dir"/*/; do
        if [[ -d "$subdir" && ! -L "$subdir" ]]; then
            search_cms "$subdir" $((depth + 1))
        fi
    done
}

search_cms "$(pwd)" 0
