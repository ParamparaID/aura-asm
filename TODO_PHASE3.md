# Aura Shell — Phase 3: TODO

> Phase 0: 37/37 ✅ | Phase 1: 35/35 ✅ | Phase 2: 48/48 ✅
> `[x]` = выполнено, `[ ]` = ожидает.

---

## STEP 30: Wayland Server — socket и registry
- [x] `src/compositor/server.asm` — создание Wayland display socket (`$XDG_RUNTIME_DIR/wayland-N`)
- [x] `src/compositor/server.asm` — accept клиентских подключений (Unix domain socket)
- [x] `src/compositor/server.asm` — per-client state: fd, resource map, буферы ввода/вывода
- [x] `src/compositor/protocol.asm` — wire protocol: чтение/запись сообщений, маршалинг аргументов
- [x] `src/compositor/registry.asm` — wl_display: get_registry, sync, error, delete_id
- [x] `src/compositor/registry.asm` — wl_registry: advertise globals (compositor, shm, seat, xdg_wm_base, output)
- [x] `src/compositor/registry.asm` — wl_registry.bind → создание server-side ресурсов
- [x] Интеграция с event loop (epoll): listen socket + per-client fd
- [x] `tests/unit/test_compositor_server.asm` — тест: запустить сервер, подключить mock-client, получить globals
- [x] Все тесты проходят

## STEP 31: Surface Management и буферы
- [x] `src/compositor/surface.asm` — wl_compositor.create_surface → Surface object
- [x] `src/compositor/surface.asm` — wl_surface: attach, damage, commit (double buffering: pending → current)
- [x] `src/compositor/surface.asm` — frame callback (wl_callback для vsync)
- [x] `src/compositor/shm.asm` — wl_shm: advertise formats, create_pool, create_buffer
- [x] `src/compositor/shm.asm` — mmap shared memory от клиента (fd passing через SCM_RIGHTS)
- [x] `src/compositor/xdg.asm` — xdg_wm_base: get_xdg_surface, ping/pong
- [x] `src/compositor/xdg.asm` — xdg_surface: get_toplevel, ack_configure
- [x] `src/compositor/xdg.asm` — xdg_toplevel: set_title, configure (width, height, states)
- [x] `src/compositor/compositor_render.asm` — композиция: рендер mapped surfaces на canvas (Z-order), frame callbacks
- [x] `src/canvas/rasterizer.asm` — `canvas_draw_image_raw` (ARGB/XRGB, stride)
- [x] `tests/unit/test_surfaces.asm` — тест: surface, SHM pool/buffer, XDG, composite, frame callback
- [x] Все тесты проходят

## STEP 32: Input Routing и wl_seat
- [x] `src/compositor/seat.asm` — wl_seat: capabilities (keyboard, pointer, touch)
- [x] `src/compositor/keyboard.asm` — wl_keyboard: keymap, enter, leave, key, modifiers
- [x] `src/compositor/pointer.asm` — wl_pointer: enter, leave, motion, button, axis
- [x] `src/compositor/touch_server.asm` — wl_touch: down, up, motion, frame
- [x] `src/hal/linux_x86_64/libinput.asm` — чтение событий из /dev/input/* (evdev)
- [x] `src/hal/linux_x86_64/drm.asm` — DRM/KMS: modesetting, получение framebuffer, page flip
- [x] Focus management: определение focused surface, отправка enter/leave
- [x] Keyboard focus follows pointer (или click-to-focus, configurable)
- [x] `tests/unit/test_input_routing.asm` — тест: два клиента, pointer enter/leave при перемещении
- [x] Все тесты проходят

## STEP 33: Window Manager (тайловый + плавающий)
- [x] `src/compositor/wm.asm` — window manager state: список окон, Z-order, focus stack
- [x] `src/compositor/tiling.asm` — тайловый режим: binary split, master/stack layout
- [x] `src/compositor/tiling.asm` — операции: split horizontal/vertical, resize, swap, move
- [x] `src/compositor/floating.asm` — плавающий режим: drag, resize, snap-to-edge
- [x] `src/compositor/floating.asm` — snap: к краям экрана, к другим окнам, половина/четверть экрана
- [x] Переключение тайловый ↔ плавающий (per-window и глобально)
- [x] Хоткеи: Super+Enter (новый терминал), Super+Q (закрыть), Super+H/V (split), Super+Arrows (focus)
- [x] `tests/unit/test_wm.asm` — тест: добавить 3 окна, проверить tiling layout, переключить в float
- [x] Все тесты проходят

## STEP 34: Hub и виртуальные рабочие столы
- [x] `src/compositor/hub.asm` — Hub (домашний экран): widget cards, свободная компоновка
- [x] `src/compositor/hub.asm` — living widgets на Hub: clock, system monitor, quick actions
- [x] `src/compositor/workspaces.asm` — виртуальные рабочие столы (Module Spaces): до 10 штук
- [x] `src/compositor/workspaces.asm` — переключение: по номеру (Super+1..0), свайпом, через Overview
- [x] `src/compositor/workspaces.asm` — перемещение окон между рабочими столами
- [x] `src/compositor/transitions.asm` — fly-in/fly-out анимации при переключении (spring-based)
- [x] `src/compositor/overview.asm` — Overview mode (Exposé): миниатюры всех окон, three-finger swipe up
- [x] `tests/unit/test_workspaces.asm` — тест: переключение, перемещение окон, возврат в Hub
- [x] Все тесты проходят

## STEP 35: Декорации и финальная интеграция
- [ ] `src/compositor/decorations.asm` — server-side decorations: title bar, кнопки close/minimize/maximize
- [ ] `src/compositor/decorations.asm` — glassmorphism декорации: blur + rounded corners + alpha surface
- [ ] `src/compositor/decorations.asm` — touch targets для кнопок (44×44 px minimum)
- [ ] `src/compositor/cursor.asm` — курсор мыши: отрисовка поверх всех surfaces
- [ ] `src/compositor/output.asm` — wl_output: geometry, mode (resolution, refresh rate)
- [ ] Интеграция: запуск Aura Shell как compositor (заменяет Sway/Mutter)
- [ ] Интеграция: запуск XWayland для X11-приложений (опционально, через exec)
- [ ] Производительность: dirty-rect композиция, skip unchanged surfaces
- [ ] Финальный интеграционный тест: запуск Firefox внутри Aura Shell compositor
- [ ] Все тесты проходят

---

**Прогресс Phase 3: STEP 30–33 по чеклисту выполнены; далее STEP 34**
