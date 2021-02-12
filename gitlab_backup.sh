#! /bin/bash

DATA_FORMAT=`date +%Y_%m_%d`

#Имя контейнера в системе Docker:
CONTAINER_NAME="gitlab"

#Путь к каталогам gitlab
PATCH_TO_GITLAB="/srv/gitlab"

#Путь хранения бэкапов:
PATCH_TO_BAKUP="${PWD}/gitlab_files/"

#Имя образа в системе Docker:
IMAGE_NAME="gitlab/gitlab-ce"

#-------------------------------------------------------------------------------
# Глобальные переменные устанавилвающие цвет и стиль шрифта в выодимых
# сообщениях
#-------------------------------------------------------------------------------
# отключить все модификаторы
ALL_OFF="\e[1;0m"
# применить "жирный" стиль
BOLD="\e[1;1m"
# установить "красный жирный"
BRED="${BOLD}\e[1;31m"
# установить "зеленый жирный"
BGREEN="${BOLD}\e[1;32m"
# установить "синий жирный"
BBLUE="${BOLD}\e[1;34m"
# установить "фиолетовый жирный"
BVIOLET="${BOLD}\e[1;35m"

function err() {
    local mesg=$1; shift
    printf "${BRED}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

function msg() {
    local mesg=$1; shift
    printf "${BGREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

function info() {
    local mesg=$1; shift
    printf "${BBLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

function print_help {

    if [[ $2 == "--print" && $3 == "true" ]]; then
        echo -e "\n    \e[1mНАИМЕНОВАНИЕ\e[0m"
        echo -e "           $(basename --  $0) - Работа с резервными копиями GitLab"
        echo -e "\n    \e[1mСИНТАКСИС\e[0m"
        echo -e "           $(basename --  $0) [--help | [-h]]"
        echo -e "\n    \e[1mОПИСАНИЕ\e[0m"
        echo -e "\n         Скрипт создает и восстанавливает резервные копии GitLab в Docker системе:"
        echo -e " "
        echo -e "           Восстановление резервных копий полуавтоматическое. Скрипт подготовит и выставит все права"
        echo -e "           для восстановления, но процедура восстановления будет проходить без использования скрипта."
        echo -e "           Сделано это из-за опасности затирания существующих данных, если скрипт запускать полностью"
        echo -e "           в автоматическом режиме"
        echo -e " "
        echo -e "           Создание резервных копий происходит в автоматическом режиме."
        echo -e "\n    \e[1mКЛЮЧИ\e[0m"
        echo -e "           Ключи запуска программы $0"
        echo -e "\n    \e[4m--help | -h\e[24m"
        echo -e "               Вывести эту справку."
        echo -e "\n    \e[4m-bd\e[24m"
        echo -e "               Создать копию данных (сохраняется в: $PATCH_TO_BAKUP).\n"
        echo -e "\n    \e[4m-bi\e[24m"
        echo -e "               Создать копию образа (сохраняется в: $PATCH_TO_BAKUP).\n"
        echo -e "\n    \e[4m-rd\e[24m"
        echo -e "               Восстановить данные (файл .tar должен находиться в: $PATCH_TO_BAKUP)"
        exit 0
    fi
}
#-------------------------------------------------------------------------------
# Вспомогательные функции
#-------------------------------------------------------------------------------
function print_header_info {
    echo -e "---------------------------------------------------------------"
    echo -e 
    echo -e "             Работа с резервными копиями GitLab                "
    echo -e 
    echo -e "---------------------------------------------------------------"
    echo -e "   Для получения справки введите ключ --help | -h              "
    echo -e "---------------------------------------------------------------"
}
function creat_folder {

    if [[ ! -e $PATCH_TO_BAKUP ]]; then
    
        mkdir -p $PATCH_TO_BAKUP
        msg "Создана директория ${BBLUE}${PATCH_TO_BAKUP}"
        return 0
    fi
}

#-------------------------------------------------------------------------------
# Основные функции
#-------------------------------------------------------------------------------
function backup_data {

    if [[ $BACKUP_DATA_FLAG == 1 ]]; then
        echo -e "---------------------------------------------------------------"
        echo -e "                  Резервирование данных Gitlab                 "
        echo -e "---------------------------------------------------------------"

        msg "Копирование данных контейнера: ${BBLUE}${CONTAINER_NAME} ${ALL_OFF}запущена...подождите"
        docker exec -it ${CONTAINER_NAME} ${CONTAINER_NAME}-rake ${CONTAINER_NAME}:backup:create
        
        #Находим последную созданную копию и копируем
        ls -t ${PATCH_TO_GITLAB}/data/backups | grep -v \/ | head -n 1 | while read var; do echo "$var"; 
        creat_folder
        cp ${PATCH_TO_GITLAB}/data/backups/$var ${PATCH_TO_BAKUP}/$var;

        msg "Копирование данных контейнера ${BBLUE}${CONTAINER_NAME} ${ALL_OFF} завершено"
        msg "Создан файл данных: ${BBLUE}${var}  ${ALL_OFF}по пути: ${BBLUE}${PATCH_TO_BAKUP}"
        done
        return 0
    fi
}

function restore_data {

    if [[ $RESTORE_DATA_FLAG == 1 ]]; then
        echo -e "---------------------------------------------------------------"
        echo -e "                  Восстановление данных Gitlab                 "
        echo -e "---------------------------------------------------------------"

        msg "Копирование данных контейнера: ${BBLUE}${CONTAINER_NAME} ${ALL_OFF}запущена...подождите"

        #Ищем поледний бэкап, копируем в каталог GitLab
        ls -t $PATCH_TO_BAKUP | grep -v \/ | head -n 1 | while read var; do echo "$var"
        cp $PATCH_TO_BAKUP/$var $PATCH_TO_GITLAB/data/backups/$var

        # Обрежем имя бэкапа (особенность GitLab)
        TMP_NAME_BACKUP=$(echo "$var" | sed 's/_gitlab_backup.tar//')

        # Установим права (почему то именно 998 с другими выходят ошибки)
        chown 998 $PATCH_TO_GITLAB/data/backups/$var

        # Начало восстановления
        msg "Выбран файл: ${BBLUE}$var"
        info "Все файлы подготовлены!"
        echo -e "---------------------------------------------------------------"
        echo -e " В связи с опасностью потери данных и особенностями Docker.    "
        echo -e "                                                               "
        echo -e " Дальнейшие действия выполняем вручную. Для этого выполните:   "
        echo -e " ${BBLUE}docker exec -it $CONTAINER_NAME $CONTAINER_NAME-rake $CONTAINER_NAME:backup:restore BACKUP=$TMP_NAME_BACKUP ${ALL_OFF}"
        echo -e "---------------------------------------------------------------"
        #docker exec -i $CONTAINER_NAME $CONTAINER_NAME-rake $CONTAINER_NAME:backup:restore BACKUP=$TMP_NAME_BACKUP
        done
        return 0
    fi
}

function backup_img {

    if [[ $BACKUP_IMAGE_FLAG == 1 ]]; then
        echo -e "---------------------------------------------------------------"
        echo -e "                  Резервирование образа Gitlab                 "
        echo -e "---------------------------------------------------------------"

        msg "Копирование образа: ${BBLUE}${IMAGE_NAME} ${ALL_OFF}запущено...подождите"
        docker save -o ${PATCH_TO_BAKUP}${DATA_FORMAT}_img_gitlab.tar ${IMAGE_NAME}
    
        Находим последную созданную копию и копируем
        ls -t ${PATCH_TO_GITLAB}/data/backups | grep -v \/ | head -n 1 | while read var; do echo "$var";
        creat_folder
        cp ${PATCH_TO_GITLAB}/data/backups/$var ${PATCH_TO_BAKUP}/$var;

        msg "Копирование образа ${BBLUE}${IMAGE_NAME} ${ALL_OFF}завершено"
        msg "Создан файл образа: ${BBLUE}${var}  ${ALL_OFF}по пути: ${BBLUE}${PATCH_TO_BAKUP}"
        done
        return 0
    fi
}

#-------------------------------------------------------------------------------
# Чтение флагов
#-------------------------------------------------------------------------------
    until [[ -z "$1" ]]; do
        arg_used=0
        if [[ $1 == "-bd" ]]; then
            BACKUP_DATA_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "-rd" ]]; then
            RESTORE_DATA_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "-bi" ]]; then
            BACKUP_IMAGE_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "--help" || $1 == "-h" ]]; then
            HELP_FLAG="true"
            arg_used=1
        fi

        if [[ $arg_used == 0 ]]; then
            err "Ошибка! некорректный аргумент командной строки: ${BRED}$1${ALL_OFF}"
            exit 1
        fi
        shift
    done

print_header_info
print_help $0 --print $HELP_FLAG

backup_data
backup_img
restore_data