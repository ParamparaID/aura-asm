%ifndef AURA_FM_VFS_INC
%define AURA_FM_VFS_INC

%define VFS_LOCAL               1
%define VFS_SFTP                2
%define VFS_ARCHIVE             3
%define VFS_FTP                 4

; VfsProvider
%define VFS_TYPE_OFF            0
%define VFS_NAME_OFF            8
%define VFS_FN_OPEN_DIR_OFF     16
%define VFS_FN_READ_ENTRY_OFF   24
%define VFS_FN_CLOSE_DIR_OFF    32
%define VFS_FN_STAT_OFF         40
%define VFS_FN_READ_FILE_OFF    48
%define VFS_FN_WRITE_FILE_OFF   56
%define VFS_FN_MKDIR_OFF        64
%define VFS_FN_RMDIR_OFF        72
%define VFS_FN_UNLINK_OFF       80
%define VFS_FN_RENAME_OFF       88
%define VFS_FN_COPY_OFF         96
%define VFS_PROVIDER_SIZE       104

; DirEntry (288 bytes)
%define DE_NAME_OFF             0
%define DE_NAME_LEN_OFF         256
%define DE_TYPE_OFF             260
%define DE_SIZE_OFF             264
%define DE_MTIME_OFF            272
%define DE_MODE_OFF             280
%define DE_UID_OFF              284
%define DE_GID_OFF              288
%define DE_HIDDEN_OFF           292
%define DIR_ENTRY_SIZE          296

; Compare result entry
%define CMP_NAME_OFF            0
%define CMP_STATUS_OFF          256
%define CMP_SIZE_LEFT_OFF       264
%define CMP_SIZE_RIGHT_OFF      272
%define CMP_ENTRY_SIZE          280

%define CMP_ONLY_LEFT           1
%define CMP_ONLY_RIGHT          2
%define CMP_SAME                3
%define CMP_DIFFERENT           4

%define VFS_MAX_PATH            1024
%define VFS_MAX_PROVIDERS       8
%define VFS_MAX_DIR_ENTRIES     512

; struct stat offsets (x86_64 Linux)
%define ST_MODE_OFF             24
%define ST_UID_OFF              28
%define ST_GID_OFF              32
%define ST_SIZE_OFF             48
%define ST_MTIME_OFF            88
%define ST_STRUCT_SIZE          144

%endif
