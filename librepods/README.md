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

Installation (clone omarchy-pods si besoin, applique le patch, compile, installe dans
`~/.local` et redémarre le service) :

```sh
./librepods/install.sh
```
