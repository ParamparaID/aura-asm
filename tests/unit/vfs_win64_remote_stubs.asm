; vfs_win64_remote_stubs.asm — omit SFTP/archive providers in minimal Win64 links
section .text
global sftp_provider_get
global archive_provider_get

sftp_provider_get:
archive_provider_get:
    xor eax, eax
    ret
