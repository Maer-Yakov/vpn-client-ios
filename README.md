# VPN Client для iOS

Тот же клиент, что и Android-приложение: свой сервер AmneziaWG, тёмная тема, логотип, список серверов, импорт ключа и QR, чат поддержки [t.me/Maer_VPN_bot](https://t.me/Maer_VPN_bot).

Ключи в git не входят. Они остаются только на телефоне после импорта.

## Что умеет

- Подключение и отключение AmneziaWG, в том числе AmneziaWG 3, и обычного WireGuard.
- Импорт: QR, вставка, файл и ссылка `vpn://`.
- Несколько серверов.
- Статус «Подключено», пока системный VPN включён.
- Чат поддержки и логотип в шапке и на значке.

OpenVPN, XRay и установка сервера сюда не входят.

## Где открывать

Проект рассчитан на Mac с Xcode 16. На Windows его нельзя собрать и поставить на iPhone: Apple отдаёт подпись и Network Extension только через Xcode.

1. Откройте `VPNClient.xcodeproj`.
2. В обоих target укажите свою команду разработчика.
3. Включите capability **Network Extensions → Packet Tunnel** и App Group `group.app.vpnadmin.client` у приложения и у расширения.
4. Подключите туннель AmneziaWG, не обычный WireGuard: пакет [amneziawg-apple](https://github.com/amnezia-vpn/amneziawg-apple), продукт `WireGuardKit`. Обычный WireGuard не понимает параметры AmneziaWG 3.
5. Соберите схему VPNClient на устройство. Симулятор VPN-туннель не поднимает.

Пока `WireGuardKit` не подключён, расширение не включает туннель и не забирает интернет телефона. После подключения пакета тот же код вызывает `WireGuardAdapter`.

Минимальная версия iOS — 16.
