# [My useful scripts](https://github.com/pfzim/scripts)

`rotate.cmd`,
`rotate.sh`   - remove files olders than XX days and stay it if 1 or 15 day of month `backup-YYYY-MM-DD-any-name-here.ext`

`purge_exchanger.sh` - move files unmodified more that XX days to subfolder and remove permanently after XX days

`etc/fonts` - fontconfig settings for MS fonts with disabled antialiasing

`windows-resistry` - different Windows registry settings

`settings` - other linux configuration files

`orchestrator/` - Runbooks for System Center Orchestrator

`NetBackup/` - scripts for generate different reports


https://github.com/Disassembler0/Win10-Initial-Setup-Script/issues/250  
Receive updates for other Microsoft products (Windows 7)  
`(New-Object -ComObject Microsoft.Update.ServiceManager).AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")`

# Replace failed disk in LVM software RAID

```
  pvs
  lvs
  # delete all partitions on new disk
  fdisk /dev/sdc
  # add new (replaced) disk to LVM
  pvcreate /dev/sdc
  # add new disk to VG
  vgextend vg_raid /dev/sdc
  # remove old failed disk from VG
  vgreduce --removemissing vg_raid --force
  # activate LV
  lvchange -ay vg_raid/lv_raid5
  # start sync
  lvconvert --repair vg_raid/lv_raid5
  lvs
  pvs
```

# [rotate.sh](rotate.sh)

## Backup Rotation Script (EN)

---

### Purpose:
This script is designed to automatically delete old backup files based on specified parameters. It analyzes backup file names, extracts dates from them, and deletes files that have exceeded the specified retention period.

---

### Key Features:
1. **Deletion of Old Files:**
   - The script searches for backup files in the specified directory and deletes those that are older than the specified number of days.

2. **Exclusion of Important Files:**
   - By default, files created on the 1st and 15th of each month are not deleted (the `--no-permanent` option disables this behavior).

3. **Flexible Configuration:**
   - Allows you to specify the path to the backup directory and the retention period in days.

4. **Logging:**
   - The script outputs information about each file: whether it is kept or deleted.

---

### Usage:
```bash
./rotate.sh -p /var/backups -d 14
```

#### Parameters:
- `-p|--path`          - Path to the backup directory (required).
- `-d|--days`          - Backup retention period in days (required).
- `-n|--no-permanent`  - Disable protection for files created on the 1st and 15th of each month.
- `-h|--help`          - Display help information.

---

### Example Workflow:
1. **Input:**
   - Directory: `/var/backups`
   - Retention period: 14 days
   - Files: `backup-2023-10-01.tar.gz`, `backup-2023-10-10.tar.gz`, `backup-2023-09-20.tar.gz`

2. **Result:**
   - The file `backup-2023-09-20.tar.gz` will be deleted because it is older than 14 days.
   - The file `backup-2023-10-01.tar.gz` will be kept because it was created on the 1st (protected by default).
   - The file `backup-2023-10-10.tar.gz` will be kept because it has not exceeded the retention period.

---

### How It Works:
1. **Extracting Dates from Filenames:**
   - The script expects backup filenames to follow the pattern `backup-YYYY-MM-DD.*`, where:
     - `YYYY` is the year.
     - `MM` is the month.
     - `DD` is the day.

2. **Retention Period Check:**
   - For each file, the script calculates the date until which it should be kept (current date + retention period).
   - If the file is older than this date, it is deleted.

3. **Protection of Important Files:**
   - Files created on the 1st and 15th of each month are not deleted by default (unless the `--no-permanent` option is specified).

---

### Example Output:
```bash
Script for remove old backup files v0.09.3   pfzim (c) 2010
Today is 25.10.2023
Path: /var/backups
Days: 14
No permanent: no

backup-2023-10-01.tar.gz : never deleted
backup-2023-10-10.tar.gz : saved until 24.10.2023
backup-2023-09-20.tar.gz : deleted. expired at 4.10.2023
```

---

### Key Details:
- The script uses `awk` and `rm` utilities to process filenames and delete files.
- It supports leap years and months with varying numbers of days.
- The script provides detailed information about each file, making it easier to diagnose issues.

---

### Limitations:
- The script assumes that backup filenames strictly follow the `backup-YYYY-MM-DD.*` pattern.
- It does not support recursive file search in subdirectories.

---

### Possible Improvements:
1. Add support for recursive file search.
2. Add the ability to specify filename patterns.
3. Implement logging to a file for further analysis.

---

### Key Points:
- The script is easy to use and configure.
- Suitable for automating backup cleanup on servers.
- Flexible configuration allows it to be adapted to various tasks.

This script is a reliable tool for managing backup files and maintaining order on servers.


## Скрипт для удаления старых резервных копий (Backup Rotation Script) (RU)

---

### Назначение:
Этот скрипт предназначен для автоматического удаления старых резервных копий на основе заданных параметров. Он анализирует имена файлов резервных копий, извлекает дату из их имен и удаляет файлы, которые превысили указанный срок хранения.

---

### Основные функции:
1. **Удаление старых файлов:**
   - Скрипт ищет файлы резервных копий в указанной директории и удаляет те, которые старше заданного количества дней.
   
2. **Исключение важных файлов:**
   - По умолчанию файлы, созданные 1-го и 15-го числа каждого месяца, не удаляются (опция `--no-permanent` отключает это поведение).

3. **Гибкая настройка:**
   - Позволяет указать путь к директории с резервными копиями и срок хранения в днях.

4. **Логирование:**
   - Скрипт выводит информацию о каждом файле: сохраняется он или удаляется.

---

### Использование:
```bash
./rotate.sh -p /var/backups -d 14
```

#### Параметры:
- `-p|--path`          - Путь к директории с резервными копиями (обязательный параметр).
- `-d|--days`          - Срок хранения резервных копий в днях (обязательный параметр).
- `-n|--no-permanent`  - Отключить защиту файлов, созданных 1-го и 15-го числа каждого месяца.
- `-h|--help`          - Вывести справку по использованию скрипта.

---

### Пример работы:
1. **Входные данные:**
   - Директория: `/var/backups`
   - Срок хранения: 14 дней
   - Файлы: `backup-2023-10-01.tar.gz`, `backup-2023-10-10.tar.gz`, `backup-2023-09-20.tar.gz`

2. **Результат:**
   - Файл `backup-2023-09-20.tar.gz` будет удален, так как он старше 14 дней.
   - Файл `backup-2023-10-01.tar.gz` будет сохранен, так как он создан 1-го числа (защищен по умолчанию).
   - Файл `backup-2023-10-10.tar.gz` будет сохранен, так как он не превысил срок хранения.

---

### Логика работы:
1. **Извлечение даты из имени файла:**
   - Скрипт ожидает, что имена файлов резервных копий соответствуют шаблону `backup-YYYY-MM-DD.*`, где:
     - `YYYY` — год.
     - `MM` — месяц.
     - `DD` — день.

2. **Проверка срока хранения:**
   - Для каждого файла вычисляется дата, до которой он должен храниться (текущая дата + срок хранения).
   - Если файл старше этой даты, он удаляется.

3. **Защита важных файлов:**
   - Файлы, созданные 1-го и 15-го числа каждого месяца, по умолчанию не удаляются (если не указана опция `--no-permanent`).

---

### Пример вывода:
```bash
Script for remove old backup files v0.09.3   pfzim (c) 2010
Today is 25.10.2023
Path: /var/backups
Days: 14
No permanent: no

backup-2023-10-01.tar.gz : never deleted
backup-2023-10-10.tar.gz : saved until 24.10.2023
backup-2023-09-20.tar.gz : deleted. expired at 4.10.2023
```

---

### Особенности:
- Скрипт использует утилиты `awk` и `rm` для обработки имен файлов и их удаления.
- Поддерживается обработка високосных годов и месяцев с разным количеством дней.
- Скрипт выводит подробную информацию о каждом файле, что упрощает диагностику.

---

### Ограничения:
- Скрипт предполагает, что имена файлов резервных копий строго соответствуют шаблону `backup-YYYY-MM-DD.*`.
- Не поддерживает рекурсивный поиск файлов в поддиректориях.

---

### Возможные улучшения:
1. Добавить поддержку рекурсивного поиска файлов.
2. Добавить возможность указания маски для имен файлов.
3. Реализовать логирование в файл для последующего анализа.

---

### Ключевые моменты:
- Скрипт прост в использовании и настройке.
- Подходит для автоматизации очистки резервных копий на серверах.
- Гибкость настройки позволяет адаптировать его под различные задачи.

Этот скрипт является надежным инструментом для управления резервными копиями и поддержания порядка на серверах.
