#! /bin/bash

#Путь к образу
PATCH_TO_IMG="/home/svyatoslav/tmp/dru_img_20210205.img"
#Путь к исходникам
PATCH_TO_SRC="/home/svyatoslav/proj/quartus/cupol/3c1_v2/3c1_hps_fw"
#Каталог монтирования
MOUNT_DIR="/mnt"


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


#-------------------------------------------------------------------------------
# Основные функции
#-------------------------------------------------------------------------------
function mount_dir {
    if [[ $MOUNT_DIR_FLAG == 1 ]]; then
        LOSETUP_DEV=`sudo losetup -f --show $PATCH_TO_IMG | awk -F"/" '{print $3}'`
        echo -e "----> Устройство: ${BBLUE}$LOSETUP_DEV ${ALL_OFF}"
    
        sudo mount /dev/${LOSETUP_DEV}p2 $MOUNT_DIR
        echo -e "----> Монтирую RootFS: ${BBLUE}${LOSETUP_DEV}p2 -> $MOUNT_DIR ${ALL_OFF}"

        sudo mount /dev/${LOSETUP_DEV}p1 $MOUNT_DIR/boot
        echo -e "----> Монтирую Boot: ${BBLUE}${LOSETUP_DEV}p1 -> $MOUNT_DIR/boot ${ALL_OFF}"

        sudo mount --bind $PATCH_TO_SRC $MOUNT_DIR/boot/hps_software
        echo -e "----> Монтирую исходники: ${BBLUE}$PATCH_TO_SRC -> $MOUNT_DIR/boot/hps_software ${ALL_OFF}"
        
        return 0
    fi
}

function umount_dir {
    if [[ $UMOUNT_DIR_FLAG == 1 ]]; then

        sudo umount $MOUNT_DIR/boot/hps_software
        echo -e "----> Отмонтирую исходники: ${BBLUE}$MOUNT_DIR/boot/hps_software ${ALL_OFF}"
 
        sudo umount $MOUNT_DIR/boot
        echo -e "----> Отмонтирую Boot: ${BBLUE}$MOUNT_DIR/boot ${ALL_OFF}"
        
        sudo umount $MOUNT_DIR
        echo -e "----> Отмонтирую RootFS: ${BBLUE}$MOUNT_DIR ${ALL_OFF}"
        
        return 0
    fi
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
        
        if [[ $arg_used == 0 ]]; then
            echo "Ошибка! некорректный аргумент командной строки: ${BRED}$1${ALL_OFF}"
            exit 1
        fi
        shift
    done
    
mount_dir
umount_dir

