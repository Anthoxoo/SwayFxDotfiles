# librepods

Démon AirPods utilisé par le module OmaPods de Quickshell : il publie l'état dans
`~/.local/state/librepods/status.json` (surveillé par `quickshell/core/SysState.qml`)
et reçoit les commandes via `librepods-ctl`.

Le démon vient du fork embarqué dans
[omarchy-pods](https://github.com/thisisgm/omarchy-pods) (`daemon/`, GPL-3.0).
Ce dossier ne contient que mon patch :

- `ble-duty-cycle.patch` : quand les AirPods ne sont pas connectés, le scan BLE tourne
  par fenêtres de 10 s toutes les 5 min au lieu d'en continu. Le scan continu faisait
  publier à BlueZ chaque annonce Bluetooth du voisinage. Mesuré sur le portable :
  Quickshell passait de 9,7 % à 0,7 % de CPU, et son journal en RAM de ~20 à ~4 Mo/h.
  Les durées se règlent avec `scanWindowMs` / `scanPauseMs` dans `daemon/ble/blemanager.cpp`.

- `librepods.service` : lance le démon en `--headless`. Sans ça il chargeait son interface
  Qt/QML sur la plateforme `offscreen`, où elle ne s'affiche jamais, et se réveillait toutes
  les 10 ms. Mesuré : 3,5 % de CPU et 92 Mo avant, 0,05 % et 44 Mo après. Coupe aussi les
  logs de debug du scan BLE (plusieurs lignes par seconde dans le journal).
- `bin/omarchy` : en headless, librepods n'envoie ses notifications (batterie faible d'un
  AirPod, déconnexion) que via la commande `omarchy`. Ce relais, présent uniquement dans le
  PATH du service, les transmet à `notify-send` (donc à Quickshell).

Installation (clone omarchy-pods si besoin, applique le patch, compile, installe dans
`~/.local`, installe le service et le relais, redémarre le service) :

```sh
./librepods/install.sh
```
