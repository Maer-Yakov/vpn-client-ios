# Mvpn для iOS

Тот же клиент, что и [Android-приложение](https://github.com/Maer-Yakov/vpn-client): свой сервер AmneziaWG, тёмная тема, логотип, список серверов, импорт ключа и QR, тестовый сервер, срок подписки, сайты в обход VPN, резервная копия и чат поддержки [t.me/Maer_VPN_bot](https://t.me/Maer_VPN_bot).

Ключи в git не входят. Они остаются только на телефоне после импорта.

## Что умеет

- Подключение и отключение AmneziaWG, в том числе AmneziaWG 3, и обычного WireGuard.
- Импорт: QR, вставка, файл и ссылка `vpn://` (в том числе `expiresAt` и `panelUrl`).
- Несколько серверов, переключение активного.
- Тестовый сервер на 1 день с панели.
- Предупреждение об истечении подписки и синхронизация даты с панелью.
- Сайты в обход VPN (DNS → исключение из AllowedIPs при подключении).
- Резервная копия `mvpn-backup` (совместима с Android).
- Статус «Подключено», время сессии и счётчики трафика.
- Стартовая анимация и брендинг Mvpn.

На iPhone нет Android-режима «по приложениям». Поля приложений сохраняются в backup для совместимости, но в туннель не применяются.

OpenVPN, XRay и установка сервера сюда не входят. Обновление через APK тоже: на iOS используйте Xcode / TestFlight / App Store.

## Где открывать

Проект рассчитан на Mac с Xcode 16. На Windows его нельзя собрать и поставить на iPhone: Apple отдаёт подпись и Network Extension только через Xcode.

1. Установите на Mac **Xcode 16** и **Go** (`brew install go`). Go нужен target’у `WireGuardGoBridgeiOS`, который собирает `libwg-go.a`.
2. Откройте `VPNClient.xcodeproj`.
3. В target **VPNClient** и **PacketTunnel** укажите свою команду разработчика.
4. Включите capability **Network Extensions → Packet Tunnel** и App Group `group.app.vpnadmin.client` у приложения и у расширения.
5. Пакет AmneziaWG уже в репозитории: локальный SPM `Vendor/amneziawg-apple` (продукт `WireGuardKit`) и external target `WireGuardGoBridgeiOS`. Обычный WireGuard из App Store / zx2c4 не подставляйте — он не понимает параметры AmneziaWG 3.
6. Соберите схему **VPNClient** на **реальное устройство**. Симулятор UI покажет, но VPN-туннель не поднимает.

При первой сборке Xcode сам соберёт Go-bridge, затем `PacketTunnel` линкует `WireGuardKit` и вызывает `WireGuardAdapter`. Если видите `backendMissing` — не собрался `WireGuardGoBridgeiOS` или на Mac нет `go` в `PATH`.

Минимальная версия iOS — 16. Версия приложения — 1.7.0 (как Android v1.7.0).
