pragma Singleton
import QtQuick

QtObject {
    // Surfaces
    readonly property color bg: "#F2141416"
    // Barre translucide : swayfx floute ce qu'il y a dessous (layer_effects "qs-bar")
    readonly property color barBg: "#B8141416"
    readonly property color bgSolid: "#141416"
    readonly property color bgInset: "#0e0e10"
    readonly property color bgCard: "#18181b"
    readonly property color rowHover: "#1b1b1e"
    readonly property color hoverBg: "#242428"
    readonly property color border: "#2a2a2c"
    readonly property color sep: "#2e2e32"

    // Texte
    readonly property color fg: "#e5e5e5"
    readonly property color subtle: "#b8b8bc"
    readonly property color win: "#9a9a9e"
    readonly property color muted: "#888888"
    readonly property color disabled: "#777777"
    readonly property color placeholder: "#6e6e70"

    // Accents
    readonly property color accent: "#ff8800"
    readonly property color urgent: "#e05252"

    readonly property string fontMain: "JetBrainsMono Nerd Font"

    // Couleur avec opacité (0..1), pour les voiles et fonds translucides
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // --- Infobulles HTML (Text.RichText) : toutes les couleurs passent par le thème ---
    function hex(c) {
        return c.toString();
    }
    function tipSpan(c, text) {
        return "<span style='color:" + hex(c) + ";'>" + text + "</span>";
    }
    // Ligne de titre (accent)
    function tipTitle(text) {
        return tipSpan(accent, text);
    }
    // Ligne grisée (état inactif)
    function tipMuted(text) {
        return tipSpan(muted, text);
    }
    // Ligne "label   valeur" (label aligné sur `width` caractères)
    function tipRow(label, value, width) {
        return tipSpan(muted, String(label).padEnd(width || 8, " ")) + tipSpan(fg, value);
    }
    // Bloc monospace multi-lignes
    function tipBlock(lines) {
        return "<tt>" + lines.join("<br>") + "</tt>";
    }
}
