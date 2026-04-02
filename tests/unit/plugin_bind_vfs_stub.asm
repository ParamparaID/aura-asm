; Minimal stub: vfs_init only needs plugin_api_bind_vfs_register (no full plugin host on Win64 tests)
section .text
global plugin_api_bind_vfs_register

plugin_api_bind_vfs_register:
    ret
