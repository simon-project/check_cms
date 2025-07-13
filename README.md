# check_cms.sh

Скрипт запускается из каталога с сайтами, например, из  `/var/www` или из `/var/www/usernane/data/www`,
либо из `/var/www/username/data/www/domain.tld`, на серверах с сайтами в `/home/username` можно запустить
из `/home` или из `/home/username` - выполняет поиск известных ему CMS, их файлов конфигурации,
извлекает данные для подключения к БД, тестирует подключение и выводит следующую информацию:

* Название CMS
* Путь к файлу конфигурации
* Информация для доступа к БД
* Результат тестового подключения к БД
* Образцы команд **mysqldump** для создания дампа БД с правами пользователя и с правами root.

Если в текущем каталоге CMS не найдено - спускается на один уровень вниз во вложенные каталоги и повторяет
поиск. Максимальная глубина поиска - до пяти уровеней вложенности.

Если в текущем каталоге, где выполняется поиск, найдена CMS, искать другие CMS внутри этого каталога скрипт не будет, т.е. если есть сайт на WordPress в каталоге /var/www/user/data/www/domain.tld и форум phpBB в каталоге /var/www/user/data/www/domain.tld/forum/ - форум найден не будет.

### Запуск

Просто запускаем из нужного каталога команду

```bash
curl -s https://raw.githubusercontent.com/simon-project/check_cms/refs/heads/main/check_cms.sh | { content=$(cat); echo "$content" | md5sum | grep -q 941b189275ae7f42c23c719b909384ce && echo "$content" | bash || echo -e "\n\nMD5 checksum mismatch, probably script upgraded. Go to https://raw.githubusercontent.com/simon-project/check_cms/ for get new cmd"; }

```

Как можно видеть, запуск выполняется без сохранения скрипта на сервере. Для надежности присутствует проверка md5.

Скрипт мало тестировался, поэтому могут быть ошибки при определении CMS. 

Список CMS/CRM, которые в теории должны определяться этим скриптом:

* Abantecart
* AmiroCMS
* AmiroCMS (New)
* Bitrix
* Bitrix (new version)
* Craft
* CS-Cart
* DLE
* Drupal
* Drupal (Old)
* HostCMS
* ImageCMS
* InstantCMS
* InstantCMS (new)
* Invision Power Board
* Joomla
* Laravel
* LiveStreet
* LiveStreet (new)
* Magento
* MediaWiki
* MODX Evo
* MODX Revo
* MyBB
* NetCat
* OpenCart
* osCommerce
* phpBB
* PHPShop
* PHPShop (may be)
* PrestaShop
* PunBB (may be)
* SMF
* Symfony
* Typo3
* UMI.CMS
* vBulletin
* Webasyst
* WHMCS
* WordPress
* XenForo

* * *

