# Passation : installer la config finale sur le PC fixe (CachyOS)

> Note pour l'agent Claude Code qui tourne sur le PC fixe. Elle a été écrite par la session
> Claude Code du portable, qui a construit cette config. Tu n'as ni cette conversation ni sa
> mémoire : tout ce dont tu as besoin est ici. Lis-la en entier avant de toucher à quoi que ce soit.
> Fichier temporaire : à supprimer du dépôt quand l'installation est terminée.

## Contexte

- L'utilisateur parle **français** : réponds en français. Les textes de l'interface, du code et
  des README restent en **anglais** (choix de l'utilisateur).
- Le bureau combine SwayFX et Quickshell : barre, launcher, menus, notifications, écran de
  verrouillage, OSD. Un sélecteur de thèmes global recolore tout d'un coup (`Super+Shift+T`).
- Le dépôt est https://github.com/Anthoxoo/SwayFxDotfiles. Il est **PUBLIC** et n'a qu'une
  branche, `master`.
- La référence est le **portable** (ThinkPad T490, Debian 13, hostname `T490`), où tout
  fonctionne et a été vérifié.
- Le **PC fixe** (CachyOS, celui-ci) fait encore tourner une **ancienne** config, celle de
  l'ex-branche `cachyOS-config` (supprimée sur GitHub). D'après cette branche, il utilisait :
  - waybar et mako ;
  - hyprlock (fichier `sway/config.d/hyprlock`), gtklock, nwg-drawer ;
  - fuzzel comme launcher ;
  - `polkit-gnome` ;
  - `firewall-applet` ;
  - un écran `DP-1` en 1920x1080 à 165 Hz ;
  - une tablette OpenTabletDriver.
- **Objectif :** que le fixe tourne avec la config de `master`, identique au portable. Les
  seules différences sont celles qui dépendent du matériel.

## Règles (non négociables)

1. **Le dépôt est public : aucun secret, jamais.** Ces fichiers restent hors du dépôt :
   - `quickshell/ical.conf`, qui contient l'URL privée de l'agenda Google ;
   - `quickshell/google-oauth-client.json` ;
   - `~/.local/state/quickshell/gtasks-token.json` ;
   - tout identifiant Mozilla (AMO).

   Le `.gitignore` les couvre, mais regarde `git status` avant chaque commit. Ne demande jamais
   de clé ou de mot de passe dans le chat.
2. **Aucun thème clair, jamais** : ne pas en proposer, ne pas en créer.
3. **`~/.config` est la source de vérité.** On modifie la config en service, on teste, puis on
   la recopie dans le dépôt avec les commandes de la section « Updating the repo » du
   `README.md`. Ensuite, commit en anglais sur `master`. Pour pousser, l'utilisateur est
   d'accord en général ; demande en cas de doute.
4. **Pas de branche par machine.** Les différences vont dans les fichiers communs, en gardant
   les lignes du portable :
   - `sway/config.d/output` : les écrans des deux machines, par nom de sortie (sway ignore les
     sorties absentes) ;
   - `sway/config.d/input` : la tablette, mappée sur `DP-1` ;
   - `sway/scripts/polkit-agent.sh` : trouve l'agent polkit, KDE ou GNOME, quel que soit son
     chemin ;
   - `sway/scripts/launch-first.sh` : `Super+B` lance Zen, sinon Firefox ; `Super+V` lance
     `zed`, sinon `zeditor` ;
   - `.zshrc` : réglages conditionnés au hostname (`[[ $HOST == T490 ]]` pour le portable).
     Fais pareil avec le hostname du fixe si besoin.
5. **Ne change pas le thème de l'utilisateur pour tester sans le remettre ensuite.**
   - Avant : note `~/.config/themes/theme current` et le fond d'écran
     (`cat ~/.local/state/quickshell/wallpaper*`).
   - Après : remets les deux.
6. **`swaymsg reload` relance aussi Quickshell**, via `exec_always start-quickshell.sh`.
   - C'est sans danger, mais préviens l'utilisateur.
   - Le moteur de thèmes n'appelle jamais `reload` : il applique les couleurs avec
     `swaymsg client.*`.
7. **librepods :** ne jamais y attacher gdb, ça le fige. Il tourne en `--headless`.
8. **Audits et diagnostics :** ne rapporter que ce qui est vérifié, ne jamais gonfler la liste.

## 0. État des lieux (lecture seule, avant tout changement)

```sh
hostname; lspci | grep -iE 'vga|3d'          # GPU : NVIDIA ? (voir pièges)
swaymsg -t get_outputs | grep -E '"name"|"current_mode"' -A0
systemctl status display-manager | head -3     # SDDM normalement
ls -la ~/.config | grep -- '->'                # dossiers de config en lien symbolique ?
find ~ -maxdepth 4 -name .git -path '*wayfx*' 2>/dev/null   # où est le clone ? (ancien chemin possible : ~/Dev/other/Swayfxdotfiles)
qs --version 2>/dev/null; pacman -Q swayfx sway quickshell mako waybar 2>/dev/null
```

- **Clone existant.** Il peut être sur la branche `cachyOS-config`, dont la branche distante
  n'existe plus.
  - Regarde `git status` et `git diff`.
  - Des modifications non commitées sont des réglages propres au fixe : montre-les à
    l'utilisateur, puis reporte ce qui compte dans les fichiers communs **avant** de changer
    de branche.
- **Dossier de config en lien symbolique.** Si un dossier de `~/.config` (sway, nvim…) pointe
  vers un ancien clone, `install.sh` refuse de continuer. Demande à l'utilisateur, puis
  remplace le lien par un vrai dossier (`mv` du lien, pas `rm -r` de la cible).

## 1. Paquets

La liste complète est dans `README.md`, section « CachyOS / Arch ». Points d'attention :

- **swayfx.** Il remplace le paquet `sway` (même binaire `/usr/bin/sway`). Garde le fichier de
  session SDDM existant : si le GPU est NVIDIA, il contient sans doute `--unsupported-gpu`.
- **quickshell en 0.3.x.** Le portable tourne en 0.3.2 (révision `9b0f339`).
  - La config utilise les modules `Quickshell.Networking`, `Quickshell.Bluetooth` et
    `Quickshell.Services.{Pam,Pipewire,UPower,Mpris,Notifications,SystemTray}`.
  - Si le paquet AUR stable est plus ancien et que `Quickshell.Networking` manque (erreur
    au chargement dans `/tmp/quickshell.log`), prends `quickshell-git`.
- **Services requis :**
  - `NetworkManager` actif (`Quickshell.Networking` en dépend) ;
  - `bluez` et `bluez-utils` (`bluetoothctl`) ;
  - `upower` ;
  - `power-profiles-daemon`, pour les profils du menu batterie. Vérifie qu'il ne se bat pas
    avec un autre gestionnaire (tuned…).
- **Utilitaires appelés par les scripts :**
  - `pipewire-pulse` (`pactl`), `wireplumber` (`wpctl`), `jq`, `curl` ;
  - `wlsunset` (veilleuse) ;
  - `brightnessctl` (sans effet sans rétroéclairage, mais appelé) ;
  - `grim`, `slurp`, `swappy`, `wl-clipboard`, `libnotify` ;
  - `uv` : le script d'agenda tourne avec `uv run --script`.
- **Apparence :**
  - `adw-gtk-theme`, qui fournit `adw-gtk3-dark` ;
  - `papirus-icon-theme`, **indispensable** : les icônes Papirus-Dark-Orange du dépôt sont
    des liens vers `/usr/share/icons/Papirus/...` ;
  - `breeze`, qui fournit le curseur `breeze_cursors` ;
  - `ttf-jetbrains-mono-nerd` et `noto-fonts`.
- **Zed** s'appelle `zeditor` sur Arch, ce qui est déjà géré.
- **Anciens composants devenus inutiles :** mako, waybar, nwg-drawer, hyprlock, gtklock,
  fuzzel (optionnel). `start-quickshell.sh` tue mako, dunst, swaync, waybar, nm-applet et
  blueman-applet à chaque démarrage.
  - **Mako en particulier :** s'il est installé, D-Bus peut le lancer avant Quickshell, et il
    prend alors `org.freedesktop.Notifications`.
  - **Propose** de le désinstaller ; ne désinstalle rien sans accord.

## 2. Mettre le dépôt à jour

```sh
cd <clone> && git fetch --prune && git checkout master && git pull --ff-only
```

L'ancien `master` est un ancêtre du nouveau, donc l'avance se fait sans fusion. La branche
locale `cachyOS-config` peut être supprimée **après** l'étape 0.

## 3. Déployer

```sh
./install.sh --dry-run     # montrer le résultat à l'utilisateur
./install.sh
```

**Ce que fait `install.sh` :**
- Il copie alacritty, btop, fuzzel, gtk-3.0, gtk-4.0, nvim, quickshell, sway, themes, walls
  et zed dans `~/.config`, plus `~/.zshrc` et `~/.local/share/icons/Papirus-Dark-Orange`.
- Chaque fichier remplacé est sauvegardé dans `~/.local/state/dotfiles-backup/<date>/`.
- Il ne supprime rien, **sauf une exception** : les fichiers de `~/.config/sway/config.d/`
  absents du dépôt partent dans la sauvegarde. Sway inclut `config.d/*`, donc l'ancien
  `hyprlock` aurait gardé `$mod+l` et un swayidle concurrent.
- Il lie le thème oh-my-zsh, puis fait `theme set orange-black` (premier déploiement) ou
  `theme apply`.

**Après le déploiement, récupère dans la sauvegarde ce qui était propre au fixe :**
- **`.zshrc`.** L'ancien contenait peut-être des lignes CachyOS (par exemple un `source` de la
  config zsh CachyOS) ou des ajouts au PATH (cargo, etc.).
  - Compare et propose à l'utilisateur de remettre ce qui sert.
  - Ce qui ne concerne que le fixe va derrière un test sur le hostname.
- **`sway/config.d/autostart_applications`.**
  - L'ancien lançait `firewall-applet`. Si l'utilisateur le veut encore, ajoute une ligne
    sans effet sur le portable :
    `exec sh -c 'command -v firewall-applet >/dev/null && sleep 2 && exec firewall-applet'`.
  - Ne remets **ni** mako, ni waybar, ni nwg-drawer, ni hyprlock : Quickshell les remplace.
- **`gtk-3.0/bookmarks`** contient des chemins `/home/antoine/...`. À adapter si le nom
  d'utilisateur diffère.
- **Fonds d'écran.** Les anciens fichiers de `~/.config/walls/<dossier>` restent en place, et
  Quickshell fait défiler tout le dossier du thème. Des doublons peuvent apparaître (par
  exemple `gruvbox/gruvbox-mountain.png` et `wall_secondary.png`) : signale-les
  seulement.

## 4. Session sway

- **Écrans.** Compare `swaymsg -t get_outputs` avec `sway/config.d/output`.
  - On s'attend à `DP-1` en 1920x1080 à 165 Hz.
  - Si les noms diffèrent, **ajoute** les lignes du fixe sous le commentaire « Desktop
    (CachyOS) » sans toucher à celles du portable. Ajoute aussi la tablette dans
    `config.d/input` si besoin.
- **Vérifier la config :** `sway -C -c ~/.config/sway/config`.
- **Appliquer :** `Super+Shift+C`, ou se déconnecter et se reconnecter. Préviens l'utilisateur
  avant.
- **Quickshell :** regarde `/tmp/quickshell.log` et `qs log`.
  - Le module batterie doit être **masqué** : il ne s'affiche que si UPower voit une batterie
    de portable.
  - Le module luminosité reste, pour la veilleuse.
- **Raccourcis à tester avec l'utilisateur :**
  - `Super+D` launcher, `Super+Échap` menu d'alimentation, `Super+L` verrouillage (PAM via
    `quickshell/pam/password.conf`, `pam_unix`) ;
  - `Super+Shift+T` thèmes, `Super+Shift+W/B/V/M` menus wifi, bluetooth, audio, écrans ;
  - `Super+N` effacer les notifications, `Super+Ctrl+Espace` fond d'écran suivant ;
  - `Impr` capture d'écran.
- **GPU.**
  - **NVIDIA :** il faut `nvidia-vaapi-driver` et `LIBVA_DRIVER_NAME=nvidia`, derrière un test
    sur le hostname du fixe. Le blur de SwayFX peut coûter cher : si ça rame, demande avant
    de toucher aux réglages blur de `config.d/theme`.
  - **AMD :** rien à faire.

## 5. Thème global

- **Le moteur :** `~/.config/themes/theme` (`list | current | set <id> | next | prev | apply`),
  documenté dans `themes/README.md`. Neuf thèmes, tous sombres : orange-black, red-black, green-black,
  gruvbox, everforest, nord, rose-pine, violet, monochrome (`kanagawa` et `rosso` ont été
  renommés en `nord` et `red-black` ; les anciens noms marchent encore).
- **GTK.** Vérifie que `gsettings get org.gnome.desktop.interface gtk-theme` donne
  `adw-gtk3-dark`, et `icon-theme` la valeur du thème courant.
- **zsh.** oh-my-zsh doit être dans `~/.oh-my-zsh`.
  - S'il a été installé **après** `install.sh`, refais le lien :
    `ln -sfn ~/.config/themes/zsh/theme.zsh-theme ~/.oh-my-zsh/custom/themes/theme.zsh-theme`.
  - Le prompt et `LS_COLORS` suivent le thème dès le prompt suivant.
- **Neovim :** au premier lancement, LazyVim télécharge ses plugins. Le colorscheme `theme` se
  recharge sur SIGUSR1.
- **alacritty** doit être en version ≥ 0.14 (`[general] import`). **btop** utilise le thème
  `theme`. **Zed** utilise le thème « Theme ».

## 6. Zen et l'extension Theme Sync

L'extension pousse les couleurs du thème dans le navigateur, en direct.
- Elle est **signée par Mozilla** (non publiée) : `themes/firefox/theme-sync.xpi`, version 1.2,
  id `theme-sync@local`.
- **Ne jamais** mettre `xpinstall.signatures.required` à `false` : ce n'est pas nécessaire, et
  Zen l'ignore de toute façon.

**Installation :**
1. Lance `~/.config/themes/firefox-setup.sh`.
   - Il installe l'extension dans chaque profil Firefox et Zen (`~/.zen`, `~/.config/zen`,
     chemins Flatpak), avec l'hôte natif `theme_sync`.
   - Il écrit le manifeste de l'hôte dans `~/.mozilla/native-messaging-hosts`, plus
     `~/.zen/native-messaging-hosts` et `~/.config/zen/native-messaging-hosts` s'ils existent.
   - Zen ne reçoit **que** l'extension, pas de `userChrome.css` : celui de Firefox casserait
     l'interface de Zen.
2. Redémarre Zen.
3. Active « Theme Sync » dans `about:addons`. Une extension déposée dans le profil arrive
   **désactivée**, et l'invite pour l'activer passe facilement inaperçue.

**Vérification :**
- Zen ouvert, `pgrep -af theme-sync-host` doit montrer l'hôte.
- **S'il n'y est pas**, Zen ne trouve pas le manifeste de l'hôte :
  - Regarde le dossier de profil dans `about:support` et la console de l'extension
    (`about:debugging`).
  - Essaie l'autre dossier `native-messaging-hosts`.
  - **Zen en Flatpak ne marchera pas** (il faudrait passer par le portail) : recommande le
    paquet natif, par exemple `zen-browser-bin` sur l'AUR.

**Ce que Zen applique vraiment n'a jamais été testé.** Zen a son propre dégradé par espace de
travail et ne prend en charge l'API de thème que partiellement.
- Teste un changement de thème (puis remets celui de l'utilisateur) et décris-lui ce qui
  change.
- Un `userChrome` spécifique à Zen est possible plus tard, si l'utilisateur le demande.

**Si l'extension change un jour :**
1. Augmente `version` dans `themes/firefox/extension/manifest.json`.
2. L'utilisateur lance **lui-même** `~/.config/themes/firefox/sign.py`, avec ses identifiants
   AMO saisis dans son terminal.
3. Relance `firefox-setup.sh`.

## 7. Écran de connexion (SDDM, demande sudo : c'est l'utilisateur qui exécute)

```sh
sudo cp -r sddm-theme /usr/share/sddm/themes/omarchy
# /etc/sddm.conf.d/theme.conf :
# [Theme]
# Current=omarchy
```

Le fixe utilisait peut-être déjà ce thème : vérifie avant. Le dépôt contient maintenant le bon
`Main.qml` (avec une majuscule, comme l'attend `metadata.desktop`) et `background.png`.

## 8. Fichiers privés (agenda et tâches Google)

Ils ne sont pas dans le dépôt. L'utilisateur les copie lui-même depuis le portable (LocalSend,
`scp`…) :
- `~/.config/quickshell/ical.conf`
- `~/.config/quickshell/google-oauth-client.json`
- `~/.local/state/quickshell/gtasks-token.json` (sinon, refaire la connexion Google une fois :
  `~/.config/quickshell/scripts/ical-fetch.py --auth-tasks`, qui ouvre le navigateur)

Ensuite `chmod 600` sur les trois. **Ne jamais** les commiter, les afficher ni les envoyer
quelque part.

## 9. AirPods : librepods (optionnel)

- `librepods/install.sh` :
  - clone `omarchy-pods` ;
  - applique `ble-duty-cycle.patch` (scan BLE 10 s toutes les 5 min, au lieu d'un scan
    continu qui inonde BlueZ) ;
  - compile et installe le tout ;
  - installe le service utilisateur `librepods.service` en `--headless` et le relais de
    notifications `~/.local/share/librepods/bin/omarchy`.
- Les dépendances Arch sont en tête du script. Détails dans `librepods/README.md`.
- **Toujours `--headless`.** Sans, Qt charge son interface graphique et le processus se
  réveille toutes les ~10 ms. Mesuré sur le portable : environ 3,5 % de CPU et 92 Mo, contre
  0,05 % et 44 Mo en headless.

## 10. Liste de vérification finale

- [ ] Barre Quickshell présente : rien de waybar, notifications Quickshell (aucun mako qui
      tourne).
- [ ] Écran en `DP-1` à 165 Hz ; tablette limitée à son écran.
- [ ] Verrouillage (`Super+L`) et déverrouillage avec le mot de passe ; mise en veille
      verrouillée.
- [ ] Le changement de thème recolore barre, fenêtres, GTK, alacritty, zsh, Neovim, btop, Zed
      et Zen. Thème de l'utilisateur **remis** ensuite.
- [ ] Wifi/réseau, bluetooth, audio et écrans fonctionnent dans les menus Quickshell.
- [ ] Agenda dans le menu calendrier (si les fichiers privés ont été copiés).
- [ ] Une demande polkit (par exemple `pkexec true`) affiche bien une fenêtre
      d'authentification.
- [ ] Config en service recopiée dans le dépôt ; `git status` sans secret ; commit et push.
- [ ] Suppression de `HANDOFF-desktop.md` du dépôt quand tout est bon.

## Pièges, en bref

- **Ancien fichier `sway/config.d/hyprlock`.** `install.sh` le met de côté. Ne le remets pas.
- **Dossiers de config en liens symboliques** vers un ancien clone : `install.sh` refuse.
  Remplacer le lien par un vrai dossier, avec accord de l'utilisateur.
- **Mako installé** : il peut voler le service de notifications avant Quickshell.
- **Quickshell trop ancien** : il manque `Quickshell.Networking`.
- **`papirus-icon-theme` absent** : les dossiers orange s'affichent cassés.
- **Zed s'appelle `zeditor` sur Arch.** C'est géré, mais à vérifier si `Super+V` ne fait rien.
- **Zen en Flatpak** : la synchronisation du thème ne marche pas.
- **Zen et les extensions :** une extension déposée dans le profil arrive désactivée.
- **`swaymsg reload`** relance Quickshell (normal).
- **L'ancien `.zshrc` du fixe** est dans la sauvegarde. À relire avant de le considérer comme
  perdu.
- **Le dépôt est public** : secrets, jamais.

## Pour référence : ce qui existe déjà (fait sur le portable)

- **Thème global :**
  - moteur Python `themes/theme`, avec des modèles par application (`themes/templates/`) ;
  - fichier rendu `current/palette.json`, surveillé par Quickshell (`core/Theme.qml`) ;
  - sélecteur `modules/ThemeMenu.qml` ;
  - fonds d'écran par thème (`walls/<dossier>`, lien `themes/<id>/backgrounds`).
- **Firefox :** extension Theme Sync signée, avec son hôte natif `themes/firefox/theme-sync-host`
  (surveillance par inotify). `userChrome` lit les variables du thème. La barre d'adresse est
  élargie et le badge d'extension masqué.
- **librepods :** headless avec relais de notifications ; correctif du scan BLE.
- **Portabilité :** sorties sway par nom, `polkit-agent.sh`, `launch-first.sh`, `.zshrc`
  conditionné au hostname, batterie masquée sans batterie, `install.sh` avec sauvegardes.
- **Coût mesuré du système de thèmes :** rien au repos. Un changement de thème coûte environ
  0,2 s de CPU pour le script et 0,1 s pour Quickshell.
- **Accès à distance :** la session Claude Code du portable est joignable depuis claude.ai
  (Remote Control). L'utilisateur peut y relayer une question si quelque chose du portable
  manque.
