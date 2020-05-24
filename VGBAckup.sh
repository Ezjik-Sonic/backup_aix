#!/bin/bash
# Для работы скрипта требуется:
# 1) Создание 2  политик на Netbackup со следующими условиями 
# 1.1) Первая политика:
    # * должна иметь тип DB2 и именно она будет дергать данный
# 1.2) Вторая политика:
    # * должна разрешать забирать бекап с NFS, параметр "Follow NFS"
    # * должна иметь тип Standard
    # * должна иметь обязательный шуделлер "User Archive" 
    # * шедуллер должен охватывать 24/7. 
# 2) Создать на isilone шару в  /ifs/export/backup 
# 2.1) Добавить клиентам разрешения на запись и чтение с данных дирикторий.

####################### Скоррекировать данные значения под ОСТ
nfsAddress="NFS-SERVER"
nfsShare='/ifs/export/backup/'
backupDir='/tmp/backupvg'

policy="-p POLITIC_NAME" 
shedules="-s Archive" 

#################################################################################################

# Date, name
dateCr=$(date +%d%m%y) # День, месяц, год
name=$(hostname -s)
savevg_vg="softvg"


# files path
LOGGING='/var/log/VGBackup.log'
exclude='/etc/exclude.rootvg'
listfile="/tmp/listfile" 
mksysb_path="${backupDir}/mksysb_${name}_${dateCr}"
savevg_path="${backupDir}/softvg_${name}_${dateCr}"

# Options of bparchive
options="${policy} ${shedules} -t 0" # -t 0 - тип политки
wait_complete="-w" # не возвращать консоль пока бекап не завершится
backup_list="-f ${listfile}"


# Создаем файл с исключениями для rootvg
cat <<EOF > ${exclude}
^./tmp/
EOF

# Создаем список файлов которые необходимо отправить на ленту 
cat <<EOF > ${listfile}
${mksysb_path}
${savevg_path}
EOF

#Смонтировать НФС шару
if [ ! -d ${backupDir} ]
then
    mkdir -p ${backupDir}
fi
/usr/sbin/mount ${nfsAddress}:${nfsShare} ${backupDir}  &>> ${LOGGING}	    || (echo "Cant mount a nfs share. See to ${LOGGING}" >> ${LOGGING}   && exit) 

# Создание mksysb
/usr/bin/mksysb -i -e ${mksysb_path} &>> ${LOGGING}                          || (echo "Cant create a mksysb. See to ${LOGGING}"  >> ${LOGGING}     && exit)
# Создаем бекап пользовательско VG
/usr/bin/savevg -if ${savevg_path} ${savevg_vg} &>> ${LOGGING}               || (echo "Cant create a savevg. See to ${LOGGING}"  >> ${LOGGING}     && exit)


/usr/openv/netbackup/bin/bparchive ${wait_complete} ${options} ${backup_list}  &>> ${LOGGING}   || (echo "Cant create a savevg. See to ${LOGGING}" >> ${LOGGING}     && exit)


# Удалить файлы по завершению и отмонтировать nfs
sleep 30 
/usr/sbin/umount ${backupDir}
/usr/bin/rm ${exclude} ${listfile}
