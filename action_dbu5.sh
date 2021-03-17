#! /bin/bash

#-------------------------------------------------------------------------------
# Скрипт выполняет рутину связанную с dbu5
#
#   Используемые переменные среды:
#        1. $IP_DBU5 - адрес платы dbu5
#
#   Используемые нестандартные утилиты:
#        1. gnu-netcat
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Переменные
#-------------------------------------------------------------------------------

# Путь к образу SD dbu5
PATCH_TO_IMG="/home/svyatoslav/tmp/dru_img_20210205.img"
# Путь к исходникам проекта демона на хосте
PATCH_TO_SRC_FW="/home/svyatoslav/proj/quartus/cupol/3c1_v2/3c1_hps_fw"
# Путь к исходникам проекта демона на dbu5
PATCH_TO_SRC_FW_DBU5="/boot/hps_software"
# Каталог монтирования
MOUNT_DIR="/mnt"
# Имя скомпилированного бинарника демона для ARM
DAEMON_BUILD_ARM="dbu_daemon_armv7l"
# Порт сервера GDB Remote
GDB_REMOTE_PORT="3000"

#-------------------------------------------------------------------------------
# Вспомогательные переменные, функции
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

function print_header_info {
    echo -e "---------------------------------------------------------------"
    echo -e 
    echo -e " Автоматизация типовых действий по подготовке к работе с dbu5 "
    echo -e " Для ряда операций необходимы права root                      "
    echo -e 
    echo -e "---------------------------------------------------------------"
    echo -e "   Для получения справки введите ключ --help | -h              "
    echo -e "---------------------------------------------------------------"
}

function print_help {

    if [[ $2 == "--print" && $3 == "true" ]]; then
        echo -e "\n    \e[1mНАИМЕНОВАНИЕ\e[0m"
        echo -e "           $(basename --  $0) - Подготовка каталогов, файлов и прочего для работы с dbu5"
        echo -e "\n    \e[1mСИНТАКСИС\e[0m"
        echo -e "           $(basename --  $0) [--help | [-h]]"
        echo -e "\n    \e[1mОПИСАНИЕ\e[0m"
        echo -e "\n         Автоматизация типовых действий по подготовке к работе с dbu5"
        echo -e "\n    \e[1mКЛЮЧИ\e[0m"
        echo -e "           Ключи запуска программы $0"
        echo -e "\n    \e[4m--help | -h\e[24m"
        echo -e "               Вывести эту справку."
        echo -e "\n    \e[4m-m\e[24m"
        echo -e "               Смонтировать образ ($PATCH_TO_IMG) dbu5 в $MOUNT_DIR. Выполнить от sudo.\n"
        echo -e "               Каталог с исходниками daemon $PATCH_TO_SRC_FW будет смонтирован в $MOUNT_DIR/boot/hps_software"
        echo -e "\n    \e[4m-u\e[24m"
        echo -e "               Отмонтировать образ ($PATCH_TO_IMG) dbu5 от $MOUNT_DIR. Выполнить от sudo.\n"
        echo -e "\n    \e[4m-d\e[24m"
        echo -e "               Запустить сервер GDB Remote для $DAEMON_BUILD_ARM на стороне dbu5.\n"
        echo -e "\n    \e[4m-maked\e[24m"
        echo -e "               Запуск сборки демона dbu5.\n"
        exit 0
    fi
}

#-------------------------------------------------------------------------------
# Основные функции
#-------------------------------------------------------------------------------

# Инициализация флагов
SSH_CONNECT_STATUS=0
FILE_DAEMON_STATUS=0
RUN_DAEMON_STATUS=0

#-------------------------------------------------------------------------------
# @brief Монтирование образа SD Card dbu5 в ФС хоста
#        (сырая функция без проверок)
#-------------------------------------------------------------------------------
function mount_dir {
    if [[ $MOUNT_DIR_FLAG == 1 ]]; then
        LOSETUP_DEV=`sudo losetup -f --show $PATCH_TO_IMG | awk -F"/" '{print $3}'`
        sudo partprobe /dev/${LOSETUP_DEV}
        echo -e "----> Устройство: ${BBLUE}$LOSETUP_DEV ${ALL_OFF}"
    
        sudo mount /dev/${LOSETUP_DEV}p2 $MOUNT_DIR
        echo -e "----> Монтирую RootFS: ${BBLUE}${LOSETUP_DEV}p2 -> $MOUNT_DIR ${ALL_OFF}"

        sudo mount /dev/${LOSETUP_DEV}p1 $MOUNT_DIR/boot
        echo -e "----> Монтирую Boot: ${BBLUE}${LOSETUP_DEV}p1 -> $MOUNT_DIR/boot ${ALL_OFF}"

        sudo mount --bind $PATCH_TO_SRC_FW $MOUNT_DIR/boot/hps_software
        echo -e "----> Монтирую исходники: ${BBLUE}$PATCH_TO_SRC_FW -> $MOUNT_DIR/boot/hps_software ${ALL_OFF}"
        
        echo -e "----> Для Chroot выполнить: ${BBLUE}sudo arch-chroot $MOUNT_DIR ${ALL_OFF}"
        
        return 0
    fi
}
#-------------------------------------------------------------------------------
# @brief Отмонтирование образа SD Card dbu5 от ФС хоста 
#        (сырая функция без проверок)
#-------------------------------------------------------------------------------
function umount_dir {
    if [[ $UMOUNT_DIR_FLAG == 1 ]]; then

        sudo umount $MOUNT_DIR/boot/hps_software
        echo -e "----> Отмонтирую исходники: ${BBLUE}$MOUNT_DIR/boot/hps_software ${ALL_OFF}"
 
        sudo umount $MOUNT_DIR/boot
        echo -e "----> Отмонтирую Boot: ${BBLUE}$MOUNT_DIR/boot ${ALL_OFF}"
        
        sudo umount $MOUNT_DIR
        echo -e "----> Отмонтирую RootFS: ${BBLUE}$MOUNT_DIR ${ALL_OFF}"
        
        echo -e "----> ${BRED}ВНИМАНИЕ: ${ALL_OFF}устройство /dev/loopX отмонтировать вручную выполнив: ${BBLUE}sudo losetup -d /dev/loopX${ALL_OFF}"
        
        return 0
    fi
}

#------------------------------------------------------------------------------
# @brief Функция проверки доступности dbu5 в сети с авторизацией по ключу 
#------------------------------------------------------------------------------
function check_connect_ssh {

    ssh -q -o BatchMode=yes  -o StrictHostKeyChecking=no -o ConnectTimeout=3 $IP_DBU5 'exit 0'

    if [ $? == 0 ];then
        SSH_CONNECT_STATUS=1
    else
        echo -e "----> ${BRED}ОШИБКА: ${ALL_OFF}Нет соединения c ${BBLUE}$IP_DBU5 ${ALL_OFF}"
        echo -e "      Возможно не настроен вход без пароля"
        exit -1
    fi
    return 0
}

#------------------------------------------------------------------------------
# @brief Функция проверки доступности скомпилированного файла демона со 
#        со стороны dbu5  
#------------------------------------------------------------------------------
function check_file_daemon {

    # if ssh root@$IP_DBU5 "[ -d $PATCH_TO_SRC_FW_DBU5/bin ]"; then # Проверка наличия каталога
    if ssh root@$IP_DBU5 "[ -f $PATCH_TO_SRC_FW_DBU5/bin/$DAEMON_BUILD_ARM ]"; then
        FILE_DAEMON_STATUS=1
    else 
        echo -e "----> ${BRED}ОШИБКА: ${ALL_OFF}Файл ${BBLUE}$PATCH_TO_SRC_FW_DBU5/bin/$DAEMON_BUILD_ARM ${ALL_OFF} не найден на dbu5"
        echo -e "      Возможно не смонтирован каталог с исходниками..."
        exit -1
    fi
    return 0
}

#------------------------------------------------------------------------------
# @brief Функция проверки запущенного процесса демона 'dbu_daemon_armv'
#        и последующая его остановка
#------------------------------------------------------------------------------
function check_run_daemon {

    # Иногда при некорректном завершении отладки GDB держит процессы 
    # активными поэтому на всякий случай убиваем GDB сервер
    ssh root@$IP_DBU5 "killall gdbserver > /dev/null 2>&1 &"

    PID_DAEMON_ARM=$(ssh root@$IP_DBU5 "pgrep dbu_daemon_armv")
    if [ "${#PID_DAEMON_ARM}" -gt 0 ]; then
        echo -e "----> ${BRED}Найден процесс!${ALL_OFF} dbu_daemon_armv PID: ${BBLUE}$PID_DAEMON_ARM ${ALL_OFF}"
        echo -e "      Останавливаю процесс...перезапустите скрипт"
        ssh root@$IP_DBU5 "kill -9 $PID_DAEMON_ARM"
        exit -1
    else 
        RUN_DAEMON_STATUS=1
    fi
    return 0
}
#------------------------------------------------------------------------------
# @brief Функция подготовки dbu5 к сессии отладки через GDB Remote. Процесс
#        отладки запускается только после последовательности успешных проверок 
#------------------------------------------------------------------------------
function debug_prepare {
    if [[ $DEBUG_PREPARE_FLAG == 1 ]]; then

        check_connect_ssh
        check_file_daemon
        check_run_daemon
 
        # Основные действия, если все проверки успешны
        if [[ $SSH_CONNECT_STATUS == 1 && 
              $FILE_DAEMON_STATUS == 1 && 
              $RUN_DAEMON_STATUS  == 1 ]]; then

            echo -e "----> Запускаю GDB сервер для: ${BBLUE}$DAEMON_BUILD_ARM ${ALL_OFF}"
            ssh -n -f root@$IP_DBU5 "sh -c 'cd $PATCH_TO_SRC_FW_DBU5/bin/; nohup gdbserver localhost:$GDB_REMOTE_PORT $DAEMON_BUILD_ARM > /dev/null 2>&1 &'"
            nc -z -w2 $IP_DBU5 $GDB_REMOTE_PORT
            if [ $? == 0 ];then
                echo -e "----> Сервер доступен! Можно подключаться ${BBLUE}$IP_DBU5:$GDB_REMOTE_PORT ${ALL_OFF} "
            else
                echo -e "----> ${BRED}ОШИБКА: ${ALL_OFF}Сервер GDB не доступен ${BBLUE}$IP_DBU5 ${ALL_OFF}"
                exit -1
            fi
        fi
        
        return 0
    fi
}

#------------------------------------------------------------------------------
# @brief Функция сборки демона на плате dbu5 
#
# @note Нужно сделать проверку что все ок...как пока что хз
#------------------------------------------------------------------------------
function make_daemon_dbu5 {
    if [[ $MAKED_FLAG == 1 ]]; then

        check_connect_ssh

        # Проверка наличия каталога с исходниками на dbu5
        if ! ssh root@$IP_DBU5 "[ -d $PATCH_TO_SRC_FW_DBU5/build_arm ]"; then

            echo -e "----> ${BRED}ОШИБКА: ${ALL_OFF}Каталог ${BBLUE}$PATCH_TO_SRC_FW_DBU5/build_arm ${ALL_OFF} не найден на dbu5"
            exit -1
        fi

        # Проверка скомпилированного демона и его переименование (по сути копия последней компиляции)
        if ssh root@$IP_DBU5 "[ -f $PATCH_TO_SRC_FW_DBU5/bin/$DAEMON_BUILD_ARM ]"; then
            echo -e "----> ${BVIOLET}Найден ${ALL_OFF}скомпилированный демон переименовываю..."
            ssh -n -f root@$IP_DBU5 "sh -c 'cd $PATCH_TO_SRC_FW_DBU5/bin; mv $DAEMON_BUILD_ARM ${DAEMON_BUILD_ARM}_bak'"
        fi
        # Запустим сборку на dbu5 и вывод в std 
        echo -e "----> Команда на сборку отправлена..."
        ssh -n -f root@$IP_DBU5 "sh -c 'cd $PATCH_TO_SRC_FW_DBU5/build_arm/; make -j2 2>&1'"
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Чтение флагов
#-------------------------------------------------------------------------------
    until [[ -z "$1" ]]; do
        arg_used=0
        if [[ $1 == "-m" ]]; then
            MOUNT_DIR_FLAG=1
            arg_used=1
        fi
        
        if [[ $1 == "-u" ]]; then
            UMOUNT_DIR_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "-d" ]]; then
            DEBUG_PREPARE_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "-maked" ]]; then
            MAKED_FLAG=1
            arg_used=1
        fi

        if [[ $1 == "--help" || $1 == "-h" ]]; then
            HELP_FLAG="true"
            arg_used=1
        fi
        
        if [[ $arg_used == 0 ]]; then
            echo "Ошибка! некорректный аргумент командной строки: ${BRED}$1${ALL_OFF}"
            exit 1
        fi
        shift
    done
  
print_help $0 --print $HELP_FLAG
# print_header_info

mount_dir
umount_dir
debug_prepare
make_daemon_dbu5
